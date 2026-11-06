import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/features/organize/organize_panel.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/shell/shell_sidebar_tabs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/page_thumbnails.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where pages would land in the grid: before the page `index`, drawn in the
/// gap before the cell at `column` of `row` (`column` can be one past the row,
/// its end).
typedef PageGridSlot = ({int index, int row, int column});

/// The a6-1 grid's measures at a [width], with x counted from the start side.
@immutable
class PageGridMetrics {
  /// The grid in a canvas [width] wide.
  const new(this.width);

  /// The canvas's width.
  final double width;

  /// `grid-template-columns: repeat(6, 150px)`.
  static const double cellWidth = 150;

  /// `.fm-thumb`: 8 + 187 + 6 + a 16 px caption line + 6; the board's row pitch
  /// agrees (its marker's top sits 3 px above the second row).
  static const double cellHeight = 223;

  /// `gap: 20px 28px`, across.
  static const double gapX = 28;

  /// `gap: 20px 28px`, down.
  static const double gapY = 20;

  /// `padding: 28px 24px`, down.
  static const double paddingY = 28;

  /// `padding: 28px 24px`, across.
  static const double paddingX = 24;

  /// As many columns as fit, at least one.
  int get columns =>
      math.max(1, ((width - 2 * paddingX + gapX) / (cellWidth + gapX)).floor());

  /// `justify-content: center`: the space on either side of the columns.
  double get inset =>
      math.max(0, (width - columns * cellWidth - (columns - 1) * gapX) / 2);

  /// The top of [row] in the scrolled content.
  double rowTop(int row) => paddingY + row * (cellHeight + gapY);

  /// The middle of the gap before [column].
  double gapCentre(int column) =>
      inset + column * (cellWidth + gapX) - gapX / 2;

  /// The slot at [x] from the start side and [y] down the content, among
  /// [count] pages: the nearest gap of the row there.
  PageGridSlot slotAt(double x, double y, int count) {
    final lastRow = (count - 1) ~/ columns;
    final row = ((y - paddingY + gapY / 2) / (cellHeight + gapY)).floor().clamp(
      0,
      lastRow,
    );
    final column = ((x - inset + gapX / 2) / (cellWidth + gapX)).round().clamp(
      0,
      columns,
    );
    final index = row * columns + column;
    if (index < count) return (index: index, row: row, column: column);
    return (index: count, row: lastRow, column: count - lastRow * columns);
  }
}

/// Organize's page grid (a6-1, a6-1b): a thumbnail of every page, in the UI's
/// direction with the pages themselves never mirrored (G32).
///
/// A click selects, ⇧-click a range, ⌘-click (Ctrl-click) adds a page; the
/// arrow keys move focus, Space toggles, and each page reads "Page 5 of 64,
/// selected". A right click or a long press opens the page menu on the
/// selection. Dragging lifts the selection as a stack with its count, over
/// empty slots and an insertion marker, until the drop (Esc cancels; the edge
/// of the canvas scrolls). Touch starts a drag with a long press, so a swipe
/// scrolls. Files dragged over the grid show the same marker and go in there
/// (B104, G105).
class PageGrid extends ConsumerStatefulWidget {
  /// The pages of `viewerProvider`'s document.
  const new({super.key});

  /// `width="{{ 132 }}"`.
  static const double thumbnailWidth = 132;

  /// A thumbnail's page at most as tall as the board's A4: the cell is fixed.
  static const double thumbnailMaxHeight = 187;

  /// The width and proportion to draw [page] at: it fits the cell whatever
  /// its shape, the proportion bounded so a page of any shape keeps a size.
  static ({double width, double aspect}) fit(PageInfo page) {
    const bound = 64.0;
    final sideways = page.rotation % 180 == 90;
    final ratio = page.width > 0 && page.height > 0
        ? (sideways ? page.width / page.height : page.height / page.width)
        : 1.0;
    final aspect = ratio.clamp(1 / bound, bound);
    final widest = sideways
        ? thumbnailWidth / (aspect * PageThumbnail.sidewaysScale)
        : thumbnailMaxHeight / aspect;
    return (width: math.min(thumbnailWidth, widest), aspect: aspect);
  }

  @override
  ConsumerState<PageGrid> createState() => _PageGridState();
}

class _PageGridState extends ConsumerState<PageGrid>
    with PageThumbnails
    implements PageGridDropTarget {
  /// How close to the canvas's edge a drag scrolls.
  static const double _edgeBand = 48;

  /// How far it scrolls each tick.
  static const double _edgeStep = 12;

  /// How often, in milliseconds: not motion, so not a token.
  static const int _edgeTickMs = 16;

  /// `height: 200px` of the insertion marker.
  static const double _markerHeight = 200;

  /// `top: 268px` against the row's 271 px.
  static const double _markerTop = -3;

  /// `width: 3px`.
  static const double _markerWidth = 3;

  /// `width: 12px; height: 12px` of its dot.
  static const double _markerDot = 12;

  /// `transform: rotate(-3deg)` of the stack.
  static const double _stackAngle = -3 * math.pi / 180;

  /// `translate(4px, 4px)`, the sheet under the top one.
  static const double _stackStep = 4;

  /// `top: -10px; right: -10px` of the count.
  static const double _countInset = -10;

  /// `min-width: 24px; height: 24px` of the count.
  static const double _countSize = 24;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewport = GlobalKey();
  final Map<int, FocusNode> _nodes = {};
  late final PageGridDropSlot _slotHolder;
  late final PagesDragged _dragCount;

  /// The pages being dragged, once a drag started.
  List<int>? _dragged;

  /// Files, not pages, are over the grid.
  bool _filesOver = false;

  /// The pointer, with x from the start side and y down the canvas.
  Offset? _pointer;

  PageGridSlot? _slot;
  Timer? _edge;

  /// The page that last had focus: it stays in view when it moves.
  int? _focused;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  RenderBox? get _box =>
      _viewport.currentContext?.findRenderObject() as RenderBox?;

  OpenedDocument? get _document => ref.read(viewerProvider)?.document;

  List<int> get _order => switch (_document) {
    final document? => [
      for (var i = 0; i < document.pages.length; i++) document.pageHandle(i),
    ],
    null => const [],
  };

  @override
  void initState() {
    super.initState();
    startThumbnails();
    _dragCount = ref.read(pagesDraggedProvider.notifier);
    _slotHolder = ref.read(pageGridDropSlotProvider)..target = this;
    ref.listenManual(viewerProvider.select((view) => view?.document), (
      before,
      document,
    ) {
      final focused = _focused;
      if (document == null || focused == null) return;
      if (!(_nodes[focused]?.hasFocus ?? false)) return;
      final index = document.pageIndexOf(focused);
      if (index != null) {
        _reveal(index);
      } else if (before?.id == document.id) {
        // Its page went: focus stays in the grid, on the nearest page left.
        final gone = before!.pageIndexOf(focused);
        if (gone != null) {
          _focusPage(document, Viewer.nearestLeft(before, document, gone));
        }
      }
    });
  }

  @override
  void dispose() {
    if (identical(_slotHolder.target, this)) _slotHolder.target = null;
    if (_dragged != null) {
      HardwareKeyboard.instance.removeHandler(_onDragKey);
      // Providers do not change while the tree builds.
      final count = _dragCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => count.set(null));
    }
    _edge?.cancel();
    _scroll.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    stopThumbnails();
    super.dispose();
  }

  FocusNode _node(int handle) =>
      _nodes.putIfAbsent(handle, () => FocusNode(debugLabel: 'Page $handle'));

  /// Brings the page at [index] into view, if it is not.
  void _reveal(int index) {
    final box = _box;
    if (box == null || !_scroll.hasClients) return;
    final metrics = PageGridMetrics(box.size.width);
    final top = metrics.rowTop(index ~/ metrics.columns);
    final bottom = top + PageGridMetrics.cellHeight;
    final position = _scroll.position;
    if (top < position.pixels) {
      _scroll.jumpTo(
        math.max(position.minScrollExtent, top - PageGridMetrics.gapY),
      );
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(
        math.min(
          position.maxScrollExtent,
          bottom + PageGridMetrics.gapY - position.viewportDimension,
        ),
      );
    }
  }

  void _pressed(int handle) {
    final keys = HardwareKeyboard.instance;
    final selection = ref.read(pageSelectionProvider.notifier);
    final mac = ref.read(shortcutPlatformProvider) == ShortcutPlatform.mac;
    if (keys.isLogicalKeyPressed(LogicalKeyboardKey.space) ||
        (mac ? keys.isMetaPressed : keys.isControlPressed)) {
      selection.toggle(handle);
    } else if (keys.isShiftPressed) {
      selection.extendTo(handle, _order);
    } else {
      selection.only(handle);
    }
    _node(handle).requestFocus();
  }

  /// ← and → (the component has ↑ and ↓): the next page along, mirrored in
  /// right to left.
  KeyEventResult _onCellKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    // Move shortcuts carry modifiers; a bare arrow only moves focus.
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || keys.isControlPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final forward = (key == LogicalKeyboardKey.arrowRight) != _rtl;
    final order = _order;
    final target = index + (forward ? 1 : -1);
    final document = _document;
    if (document != null && target >= 0 && target < order.length) {
      _focusPage(document, target);
    }
    return KeyEventResult.handled;
  }

  /// Moves focus to the page at [index] of [document].
  void _focusPage(OpenedDocument document, int index) {
    _reveal(index);
    // After the frame: a page scrolled to may only now be built.
    final node = _node(document.pageHandle(index));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _showMenu(BuildContext context, int handle, Offset position) {
    if (!ref.read(selectedPagesProvider).contains(handle)) {
      ref.read(pageSelectionProvider.notifier).only(handle);
    }
    showPageMenu(context, ref, position);
  }

  /// [global] as x from the start side and y down the canvas.
  Offset? _local(Offset global) {
    final box = _box;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    return Offset(_rtl ? box.size.width - local.dx : local.dx, local.dy);
  }

  void _place(Offset local) {
    final box = _box;
    final document = _document;
    if (box == null || document == null) return;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    setState(() {
      _pointer = local;
      _slot = PageGridMetrics(box.size.width)
          .slotAt(local.dx, local.dy + offset, document.pages.length);
    });
  }

  void _startDrag(int handle, Offset global) {
    if (_dragged != null || ref.read(organizeRefusalProvider) != null) return;
    if (!ref.read(selectedPagesProvider).contains(handle)) {
      ref.read(pageSelectionProvider.notifier).only(handle);
    }
    final pages = ref.read(selectedPagesProvider);
    _dragged = pages;
    _dragCount.set(pages.length);
    HardwareKeyboard.instance.addHandler(_onDragKey);
    _moveDrag(global);
  }

  void _moveDrag(Offset global) {
    if (_dragged == null) return;
    final local = _local(global);
    if (local == null) return;
    _place(local);
    final box = _box!;
    final direction = local.dy < _edgeBand
        ? -1
        : local.dy > box.size.height - _edgeBand
        ? 1
        : 0;
    _edge?.cancel();
    _edge = direction == 0
        ? null
        : Timer.periodic(const Duration(milliseconds: _edgeTickMs), (_) {
            if (!_scroll.hasClients) return;
            final position = _scroll.position;
            _scroll.jumpTo(
              (position.pixels + direction * _edgeStep).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
            );
            final pointer = _pointer;
            if (pointer != null) _place(pointer);
          });
  }

  void _endDrag({required bool drop}) {
    final dragged = _dragged;
    if (dragged == null) return;
    final slot = _slot;
    HardwareKeyboard.instance.removeHandler(_onDragKey);
    _edge?.cancel();
    _edge = null;
    _dragCount.set(null);
    setState(() {
      _dragged = null;
      _pointer = null;
      _slot = null;
    });
    if (!drop || slot == null) return;
    // Before the first page at or after the slot that does not move with them.
    final before = _order
        .skip(slot.index)
        .where((page) => !dragged.contains(page))
        .firstOrNull;
    unawaited(ref.read(pageCommandsProvider.notifier).moveBefore(before));
  }

  bool _onDragKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _endDrag(drop: false);
      return true;
    }
    return false;
  }

  @override
  bool hover(Offset? global) {
    final box = _box;
    final local = global == null ? null : _local(global);
    final over =
        global != null &&
        local != null &&
        box != null &&
        ref.read(organizeRefusalProvider) == null &&
        box.size.contains(box.globalToLocal(global));
    if (over) {
      _filesOver = true;
      _place(local);
    } else if (_filesOver) {
      setState(() {
        _filesOver = false;
        _pointer = null;
        _slot = null;
      });
    }
    return over;
  }

  @override
  bool drop(List<String> paths, Offset global) {
    if (!hover(global)) return false;
    final slot = _slot!;
    final order = _order;
    hover(null);
    unawaited(
      ref
          .read(pageCommandsProvider.notifier)
          .insertFiles(
            paths,
            after: slot.index == 0 ? null : order[slot.index - 1],
          ),
    );
    return true;
  }

  /// a6-1b's status: what a drop would do.
  String _status(AppLocalizations l10n, RegionFormat format) {
    final before = _slot!.index;
    final document = _document!;
    final count = document.pages.length;
    final dragged = _dragged;
    if (dragged == null) {
      return before >= count
          ? l10n.organizeDropFilesEnd
          : l10n.organizeDropFilesBefore(format.integer(before + 1));
    }
    final order = _order;
    final pages = bidiIsolate(
      pageRanges([
        for (var i = 0; i < order.length; i++)
          if (dragged.contains(order[i])) i,
      ], format),
    );
    // The first page that stays, as the drop will find it.
    var target = before;
    while (target < count && dragged.contains(order[target])) {
      target++;
    }
    return target >= count
        ? l10n.organizeDropMoveEnd(dragged.length, pages)
        : l10n.organizeDropMoveBefore(
            dragged.length,
            pages,
            format.integer(target + 1),
          );
  }

  Widget _cell(
    BuildContext context,
    OpenedDocument document,
    int index,
    RegionFormat format,
    AppLocalizations l10n,
    Set<int> selected,
  ) {
    final page = document.pages[index];
    final handle = document.pageHandle(index);
    final fit = PageGrid.fit(page);
    final thumbnail = PageThumbnail(
      page: index + 1,
      label: pageLabel(document, index, format),
      width: fit.width,
      aspect: fit.aspect,
      rotation: page.rotation,
      selected: selected.contains(handle),
      state: _dragged?.contains(handle) ?? false
          ? PageThumbnailState.placeholder
          : PageThumbnailState.idle,
      orientation: ThumbnailOrientation.horizontal,
      semanticLabel: l10n.shellPageOf(
        format.integer(index + 1),
        format.integer(document.pages.length),
      ),
      focusNode: _node(handle),
      onPressed: () => _pressed(handle),
      child: switch (thumbnailOf(handle)) {
        final image? => RawImage(image: image, fit: BoxFit.fill),
        // A blank page until the thumbnail arrives, never the placeholder
        // lines, which would look like content.
        null => const SizedBox.expand(),
      },
    );
    return ThumbnailReporter(
      key: ValueKey(handle),
      handle: handle,
      onBuilt: thumbnailBuilt,
      onGone: thumbnailGone,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) {
          if (focused) _focused = handle;
        },
        onKeyEvent: (_, event) => _onCellKey(index, event),
        // A mouse drags at once, a finger after a long press.
        child: GestureDetector(
          supportedDevices: const {PointerDeviceKind.mouse},
          onPanStart: (details) => _startDrag(handle, details.globalPosition),
          onPanUpdate: (details) => _moveDrag(details.globalPosition),
          onPanEnd: (_) => _endDrag(drop: true),
          onPanCancel: () => _endDrag(drop: false),
          onSecondaryTapUp: (details) =>
              _showMenu(context, handle, details.globalPosition),
          child: GestureDetector(
            supportedDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
            },
            onLongPressMoveUpdate: (details) {
              if (_dragged == null) {
                _startDrag(handle, details.globalPosition);
              } else {
                _moveDrag(details.globalPosition);
              }
            },
            onLongPressEnd: (details) {
              if (_dragged != null) {
                _endDrag(drop: true);
              } else {
                _showMenu(context, handle, details.globalPosition);
              }
            },
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: thumbnail,
            ),
          ),
        ),
      ),
    );
  }

  /// a6-1b's stack: three sheets, the top one the first page, with the count.
  Widget _stack(FermanTheme theme, List<int> dragged, RegionFormat format) {
    Widget sheet(double by, List<BoxShadow> shadow, {Widget? child}) =>
        Transform.translate(
          offset: Offset(by, by),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.pageColors.pageBg,
              boxShadow: shadow,
            ),
            child: child ?? const SizedBox.expand(),
          ),
        );
    return Transform.rotate(
      angle: _stackAngle,
      child: SizedBox(
        width: PageGrid.thumbnailWidth,
        height: PageGrid.thumbnailMaxHeight,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            sheet(2 * _stackStep, theme.elevation.shadowSm),
            sheet(_stackStep, theme.elevation.shadowSm),
            sheet(
              0,
              theme.elevation.shadowDrag,
              child: switch (thumbnailOf(dragged.first)) {
                final image? => RawImage(image: image, fit: BoxFit.fill),
                null => null,
              },
            ),
            PositionedDirectional(
              top: _countInset,
              end: _countInset,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: _countSize,
                  minHeight: _countSize,
                ),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space1_5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colors.accent,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusSm),
                  ),
                ),
                child: Text(
                  format.integer(dragged.length),
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textOnAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    final selected = ref.watch(pageSelectionProvider);
    // Kept alive for the gestures, which read it.
    ref.watch(organizeRefusalProvider);
    if (document == null) return const SizedBox.shrink();
    return LayoutBuilder(
      key: _viewport,
      builder: (context, constraints) {
        final metrics = PageGridMetrics(constraints.maxWidth);
        final slot = _slot;
        final pointer = _pointer;
        final dragged = _dragged;
        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              label: l10n.organizeGridLabel,
              child: GridView.builder(
                controller: _scroll,
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: metrics.inset,
                  vertical: PageGridMetrics.paddingY,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: metrics.columns,
                  mainAxisSpacing: PageGridMetrics.gapY,
                  crossAxisSpacing: PageGridMetrics.gapX,
                  mainAxisExtent: PageGridMetrics.cellHeight,
                ),
                itemCount: document.pages.length,
                // Each cell moves with its page: its focus and its bitmap too.
                findChildIndexCallback: (key) => key is ValueKey<int>
                    ? document.pageIndexOf(key.value)
                    : null,
                itemBuilder: (context, index) =>
                    _cell(context, document, index, format, l10n, selected),
              ),
            ),
            if (slot != null)
              PositionedDirectional(
                start: metrics.gapCentre(slot.column) - _markerWidth / 2,
                top:
                    metrics.rowTop(slot.row) +
                    _markerTop -
                    (_scroll.hasClients ? _scroll.offset : 0),
                width: _markerWidth,
                height: _markerHeight,
                child: ExcludeSemantics(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colors.accent,
                            borderRadius: BorderRadius.all(
                              Radius.circular(theme.radius.radiusSm),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: -_markerDot / 2,
                        start: (_markerWidth - _markerDot) / 2,
                        child: Container(
                          width: _markerDot,
                          height: _markerDot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (dragged != null && pointer != null)
              PositionedDirectional(
                start: pointer.dx - PageGrid.thumbnailWidth / 2,
                top: pointer.dy - PageGrid.thumbnailMaxHeight / 2,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: _stack(theme, dragged, format),
                  ),
                ),
              ),
            if (slot != null)
              PositionedDirectional(
                bottom: theme.space.space5,
                end: theme.space.space5,
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: theme.space.space3,
                      vertical: theme.space.space2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colors.surfaceInverse,
                      borderRadius: BorderRadius.all(
                        Radius.circular(theme.radius.radiusMd),
                      ),
                    ),
                    child: Text(
                      _status(l10n, format),
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.textInverse,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
