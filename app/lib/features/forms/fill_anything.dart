import 'dart:async';

import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart' show markColorOf;
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fill_anything.g.dart';

/// The lines, boxes, check boxes and combs drawn on page [page] (by
/// [PageInfo.handle]) of the open document (a5-4), read again after each
/// step.
@riverpod
Future<FillTargets> pageFillTargets(Ref ref, int page) async {
  final document = ref.watch(openDocumentProvider.select((d) => d?.id));
  ref.watch(documentEditorProvider.select((s) => s.history.current));
  if (document == null) return const FillTargets();
  return await ref.read(engineServiceProvider).fillTargets(document, page);
}

/// The target of [targets] at [point] (page points), lines with some slack.
FillTarget? fillTargetAt(List<FillTarget> targets, Offset point) {
  for (final target in targets) {
    final slack = target.kind == FillTargetKind.line
        ? FillAnythingOverlay.lineSlack
        : 0.0;
    final area = target.kind == FillTargetKind.line
        ? Rect.fromLTRB(
            target.rect.left,
            target.rect.top - FillAnythingOverlay.lineReach,
            target.rect.right,
            target.rect.bottom + slack,
          )
        : target.rect.inflate(slack);
    if (area.contains(point)) return target;
  }
  return null;
}

/// Where text typed for [target] goes, in page points, at [fontSize]: on a
/// line's baseline, inside a box or comb.
Rect fillTextRect(FillTarget target, double fontSize) {
  final height = fontSize * FillAnythingOverlay.lineHeight;
  return switch (target.kind) {
    FillTargetKind.line => Rect.fromLTRB(
      target.rect.left,
      target.rect.top - height,
      target.rect.right,
      target.rect.top,
    ),
    _ => target.rect,
  };
}

/// What is being typed on the page.
final class _Draft {
  new({required this.page, required this.rect, required this.ink, this.cells});

  final int page;
  final Rect rect;
  final AnnotationColor ink;
  final int? cells;
}

/// Fill anything's layer over pages without fields (a5-4): the line, box or
/// comb under the pointer shows; a click types on a line's baseline or in a
/// box, a comb takes one character a cell, and a check box takes the mark.
/// What it places are W2's text boxes and ink marks, editable in Comment
/// until saved.
// shortcut: no floating bar for a placed text's size, font and delete
// (a5-4); Comment mode edits and deletes them; upgrade with B206.
class FillAnythingOverlay extends ConsumerStatefulWidget {
  /// The layer over [view].
  const new({required this.view, super.key});

  /// The canvas as it stands.
  final ViewerState view;

  /// How far above a line the pointer still finds it, in points.
  static const double lineReach = 14;

  /// How far around a target the pointer still finds it, in points.
  static const double lineSlack = 3;

  /// The size of placed text, in points (a5-4's "10 pt").
  static const double fontSize = 10;

  /// A text box's height for its size.
  static const double lineHeight = 1.5;

  /// The width of text placed off any line, in points.
  static const double freeWidth = 180;

  /// A digit's advance for its size, to spread a comb's typing over its
  /// cells while it is typed.
  static const double combAdvance = 0.6;

  /// The box of a mark placed off any check box, in points.
  static const double markSize = 12;

  @override
  ConsumerState<FillAnythingOverlay> createState() =>
      _FillAnythingOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ViewerState>('view', view));
  }
}

class _FillAnythingOverlayState extends ConsumerState<FillAnythingOverlay> {
  /// What [dispose] needs, when `ref` no longer answers.
  late final FormCommands _keptCommands;
  (int, FillTarget)? _hover;
  _Draft? _draft;
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'FillAnything');

  /// Takes the typing before closing, quitting and saving.
  late final DocumentEditor _editor;

  @override
  void initState() {
    super.initState();
    _keptCommands = ref.read(formCommandsProvider.notifier);
    _editor = ref.read(documentEditorProvider.notifier)..holdDraft(_take);
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  /// A view keyed by its document goes when another document shows; what
  /// was being typed goes to its own document.
  @override
  void dispose() {
    _editor.dropDraft(_take);
    _commit(disposing: true);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  ViewerState get _view => widget.view;

  /// The page under [local] and the point in it.
  (int, Offset)? _pageAt(Offset local) {
    final onCanvas = local + _view.offset;
    for (final (page, rect) in _view.placement.rects.indexed) {
      if (rect != null && rect.contains(onCanvas)) {
        return (page, (onCanvas - rect.topLeft) / _view.scale);
      }
    }
    return null;
  }

  List<FillTarget> _targets(int page) =>
      ref
          .watch(pageFillTargetsProvider(_view.document.pageHandle(page)))
          .value
          ?.targets ??
      const [];

  FillTarget? _targetAt(int page, Offset point) =>
      ref.read(fillToolsStateProvider).snap
      ? fillTargetAt(
          ref
                  .read(
                    pageFillTargetsProvider(_view.document.pageHandle(page)),
                  )
                  .value
                  ?.targets ??
              const [],
          point,
        )
      : null;

  void _hovered(Offset local) {
    final at = _pageAt(local);
    final target = at == null ? null : _targetAt(at.$1, at.$2);
    final next = at == null || target == null ? null : (at.$1, target);
    if (next?.$2 != _hover?.$2) setState(() => _hover = next);
  }

  void _tapped(Offset local) {
    _commit();
    Focus.maybeOf(context)?.requestFocus();
    final at = _pageAt(local);
    if (at == null || ref.read(fillRefusalProvider) != null) return;
    final (page, point) = at;
    final tools = ref.read(fillToolsStateProvider);
    final tool = tools.tool == FillTool.fields ? FillTool.text : tools.tool;
    final target = _targetAt(page, point);
    final commands = ref.read(formCommandsProvider.notifier);
    final ink = markColorOf(tools.ink.colorIn(context.ferman));
    final markBox =
        target != null &&
            (target.kind == FillTargetKind.check ||
                target.kind == FillTargetKind.box)
        ? target.rect
        : Rect.fromCenter(
            center: point,
            width: FillAnythingOverlay.markSize,
            height: FillAnythingOverlay.markSize,
          );
    switch (tool) {
      case FillTool.check || FillTool.cross || FillTool.dot:
        unawaited(commands.placeMark(page, markBox, tool, ink));
        return;
      case _ when target?.kind == FillTargetKind.check:
        unawaited(commands.placeMark(page, markBox, FillTool.check, ink));
        return;
      case _:
        break;
    }
    const size = FillAnythingOverlay.fontSize;
    final rect = target == null
        ? Rect.fromLTWH(
            point.dx,
            point.dy - size,
            FillAnythingOverlay.freeWidth,
            size * FillAnythingOverlay.lineHeight,
          )
        : fillTextRect(target, size);
    final cells = target?.kind == FillTargetKind.comb && tools.comb
        ? target!.cells
        : null;
    if (tool == FillTool.date) {
      final format = RegionFormat.forRegion(ref.read(regionProvider).region);
      unawaited(
        commands.placeText(
          page,
          rect,
          format.date(DateTime.now()),
          fontSize: size,
          ink: ink,
        ),
      );
      return;
    }
    setState(() {
      _draft = _Draft(page: page, rect: rect, ink: ink, cells: cells);
      _text.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _commit({bool disposing = false}) =>
      unawaited(_take(disposing: disposing));

  /// Places what was typed in the draft, if anything.
  Future<void> _take({bool disposing = false}) {
    final draft = _draft;
    if (draft == null) return Future.value();
    _draft = null;
    final text = _text.text.trim();
    if (!disposing && mounted) setState(() {});
    if (text.isEmpty) return Future.value();
    return _keptCommands.placeText(
      draft.page,
      draft.rect,
      text,
      fontSize: FillAnythingOverlay.fontSize,
      ink: draft.ink,
      cells: draft.cells,
      on: _view.document,
    );
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _text.clear();
      _focus.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Rect? _onCanvas(int page, Rect box) {
    final rect = _view.placement.rects.elementAtOrNull(page);
    if (rect == null) return null;
    return Rect.fromLTRB(
      rect.left + box.left * _view.scale,
      rect.top + box.top * _view.scale,
      rect.left + box.right * _view.scale,
      rect.top + box.bottom * _view.scale,
    ).shift(-_view.offset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final page = theme.pageColors;
    // Ask for the targets of the pages in view.
    for (final (index, rect) in _view.placement.rects.indexed) {
      if (rect != null && rect.overlaps(_view.visible)) _targets(index);
    }
    final hover = _hover;
    final hoverBox = hover == null ? null : _onCanvas(hover.$1, hover.$2.rect);
    final draft = _draft;
    final draftBox = draft == null ? null : _onCanvas(draft.page, draft.rect);
    final inkColor = ref
        .watch(fillToolsStateProvider.select((t) => t.ink))
        .colorIn(theme);
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onHover: (event) => _hovered(event.localPosition),
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _tapped(details.localPosition),
        child: Stack(
          children: [
            if (hoverBox != null && draft == null)
              PositionedDirectional(
                start: hoverBox.left,
                top: hoverBox.top,
                width: hoverBox.width,
                height: hoverBox.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: page.formFieldBg,
                      border: Border.all(
                        color: page.formFieldBorder,
                        width: theme.border.borderWidth,
                      ),
                    ),
                  ),
                ),
              ),
            if (draftBox != null)
              PositionedDirectional(
                start: draftBox.left,
                top: draftBox.top,
                width: draftBox.width,
                height: draftBox.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: page.pageBg,
                    border: Border.all(
                      color: page.editBox,
                      width: theme.border.borderWidthStrong,
                    ),
                  ),
                  child: Focus(
                    onKeyEvent: _key,
                    child: FieldInput(
                      controller: _text,
                      focusNode: _focus,
                      inputFormatters: [
                        if (draft?.cells case final cells?)
                          LengthLimitingTextInputFormatter(cells),
                      ],
                      style: theme.typography.body.copyWith(
                        fontSize: FillAnythingOverlay.fontSize * _view.scale,
                        color: inkColor,
                        letterSpacing: draft?.cells == null
                            ? null
                            : draftBox.width / draft!.cells! -
                                  FillAnythingOverlay.fontSize *
                                      _view.scale *
                                      FillAnythingOverlay.combAdvance,
                      ),
                      onSubmitted: (_) => _focus.unfocus(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
