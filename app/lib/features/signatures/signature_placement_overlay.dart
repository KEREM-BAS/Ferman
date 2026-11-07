import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:ferman/features/signatures/sign_tools.dart';
import 'package:ferman/features/signatures/signature_preview.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A signature's box before it is resized, in points (a5-3d: 62 × 16 mm):
/// its width …
const double signatureWidth = 176;

/// … and height.
const double signatureHeight = 45;

/// Initials' box before it is resized, in points: its width …
const double initialsWidth = 72;

/// … and height.
const double initialsHeight = 36;

/// The smallest side a resize leaves, in points.
const double smallestSide = 8;

/// What a drag on the draft does.
enum _Drag { move, resize, turn }

/// Places what `signaturePlacementProvider` holds (a5-3d), over the reader's
/// pages and in their own geometry, which never mirrors. A click makes a draft
/// there, fitted into an unsigned signature field under it; the draft moves by
/// a drag, resizes from its corners with its proportions kept, turns from its
/// round handle in 15° steps with ⇧, and nudges with the arrows, 1 pt or 10 pt
/// with ⇧. Enter, a click beside it, another choice or leaving Fill & Sign
/// places it as one step (M4 decision 16); Esc drops it, then ends placing.
class SignaturePlacementOverlay extends ConsumerStatefulWidget {
  /// The overlay.
  const new({super.key});

  /// The handle's stem (`height: 21px`) and the gap above the box (`5px`).
  static const double stem = 21;

  /// The round handle (`12px`), whose centre is this far above the box.
  static const double knobReach = 28;

  /// The round handle's size.
  static const double knob = 12;

  /// A corner handle's size (`9px`).
  static const double corner = 9;

  /// How near a handle a press takes it, on screen.
  static const double grab = 8;

  /// The frame's width (`outline: 1.5px`).
  static const double frame = 1.5;

  /// The turn steps with ⇧.
  static const double step = 15;

  /// The share of the box the ink takes, as the engine fits it.
  static const double inkShare = 0.8;

  @override
  ConsumerState<SignaturePlacementOverlay> createState() =>
      _SignaturePlacementOverlayState();
}

class _SignaturePlacementOverlayState
    extends ConsumerState<SignaturePlacementOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'SignaturePlacementOverlay');

  int? _page;
  Rect? _box;
  double _tilt = 0;
  String? _field;

  _Drag? _drag;
  Offset _from = Offset.zero;
  Rect _boxAtStart = Rect.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _page = null;
    _box = null;
    _tilt = 0;
    _field = null;
    _drag = null;
  });

  /// The page under [local] and the point on it.
  (int, Offset)? _pointAt(ViewerState view, Offset local) {
    for (final (index, rect) in view.placement.rects.indexed) {
      final page = rect?.shift(-view.offset);
      if (page != null && page.contains(local)) {
        return (index, (local - page.topLeft) / view.scale);
      }
    }
    return null;
  }

  /// [local] as a point of the draft's page.
  Offset? _onPage(ViewerState view, Offset local) {
    final rect = view.placement.rects
        .elementAtOrNull(_page ?? -1)
        ?.shift(-view.offset);
    return rect == null ? null : (local - rect.topLeft) / view.scale;
  }

  /// [point] of the page in the draft's own, unturned frame.
  Offset _unturned(Offset point) {
    final box = _box!;
    final angle = -_tilt * math.pi / 180;
    final d = point - box.center;
    return box.center +
        Offset(
          d.dx * math.cos(angle) - d.dy * math.sin(angle),
          d.dx * math.sin(angle) + d.dy * math.cos(angle),
        );
  }

  /// A new draft of [signature] at [point] of [page], in the unsigned
  /// signature field there if there is one.
  Future<void> _start(
    SavedSignature signature,
    ViewerState view,
    int page,
    Offset point,
  ) async {
    final info = view.document.pages.elementAtOrNull(page);
    if (info == null) return;
    final handle = view.document.pageHandle(page);
    FieldInfo? field;
    FieldWidget? widget;
    try {
      final form = await ref
          .read(engineServiceProvider)
          .formFields(view.document.id);
      for (final each in form.fields) {
        if (each.kind != FieldKind.signature ||
            each.signed ||
            each.signature != null) {
          continue;
        }
        for (final place in each.widgets) {
          if (place.page == handle && place.rect.contains(point)) {
            field = each;
            widget = place;
          }
        }
      }
    } on EngineException {
      // No form to read: the signature goes where it was clicked.
    }
    if (!mounted) return;
    final (width, height) = signature.initials
        ? (initialsWidth, initialsHeight)
        : (signatureWidth, signatureHeight);
    setState(() {
      _page = page;
      _tilt = 0;
      _field = field?.name;
      _box =
          widget?.rect ??
          keptOnPage(
            Rect.fromCenter(center: point, width: width, height: height),
            Size(info.width, info.height),
          );
    });
  }

  /// Places the draft as one step and, with [end], ends placing.
  void _commit(SavedSignature signature, {bool end = true}) {
    final view = ref.read(viewerProvider);
    final page = _page;
    final box = _box;
    if (view == null || page == null || box == null) return;
    final document = view.document.id;
    final handle = view.document.pageHandle(page);
    final l10n = AppLocalizations.of(context);
    final step = signature.initials
        ? l10n.stepAddInitials
        : l10n.stepAddSignature;
    final engine = ref.read(engineServiceProvider);
    final toasts = ref.read(toastNoticesProvider.notifier);
    final name = ref.read(shellDocumentsProvider).active?.name ?? '';
    final draft = NewSignature(
      rect: box,
      ink: signature.ink,
      color: signature.color,
      author: yourNameOf(ref),
      tilt: _tilt,
      initials: signature.initials,
      field: _field,
    );
    _clear();
    if (end) ref.read(signaturePlacementProvider.notifier).end();
    unawaited(
      ref
          .read(documentEditorProvider.notifier)
          .pageChange(
            document,
            () async => (await engine.addSignature(
              document,
              handle,
              draft,
              step,
            )).revision,
          )
          .then((failure) {
            if (failure != null) showPageChangeFailure(toasts, failure, name);
          }),
    );
  }

  void _onTapUp(ViewerState view, TapUpDetails details) {
    final signature = ref.read(signaturePlacementProvider);
    if (signature == null) return;
    if (_box != null) {
      final point = _onPage(view, details.localPosition);
      if (point == null || !_box!.contains(_unturned(point))) {
        _commit(signature);
      }
      return;
    }
    final at = _pointAt(view, details.localPosition);
    if (at != null) unawaited(_start(signature, view, at.$1, at.$2));
  }

  void _onPanStart(ViewerState view, DragStartDetails details) {
    final box = _box;
    final point = _onPage(view, details.localPosition);
    if (box == null || point == null) return;
    final local = _unturned(point);
    final reach = SignaturePlacementOverlay.grab / view.scale;
    final knob = box.topCenter.translate(
      0,
      -SignaturePlacementOverlay.knobReach / view.scale,
    );
    final corners = [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ];
    _Drag? drag;
    if ((local - knob).distance <= reach) {
      drag = _Drag.turn;
    } else if (corners.any((c) => (local - c).distance <= reach)) {
      drag = _Drag.resize;
    } else if (box.contains(local)) {
      drag = _Drag.move;
    }
    setState(() {
      _drag = drag;
      _from = local;
      _boxAtStart = box;
    });
  }

  void _onPanUpdate(ViewerState view, DragUpdateDetails details) {
    final drag = _drag;
    final point = _onPage(view, details.localPosition);
    if (drag == null || point == null) return;
    final start = _boxAtStart;
    setState(() {
      switch (drag) {
        case _Drag.move:
          _box = start.shift(point - _from);
        case _Drag.resize:
          // shortcut: the opposite corner is taken in the page's frame, so a
          // turned draft grows a little off its corner; upgrade if turns past
          // a few degrees are common.
          final anchor = Offset(
            _from.dx < start.center.dx ? start.right : start.left,
            _from.dy < start.center.dy ? start.bottom : start.top,
          );
          final scale = math.max(
            (point.dx - anchor.dx).abs() / start.width,
            (point.dy - anchor.dy).abs() / start.height,
          );
          final least = smallestSide / start.shortestSide;
          final size = start.size * math.max(scale, least);
          _box = Rect.fromPoints(
            anchor,
            anchor +
                Offset(
                  _from.dx < start.center.dx ? -size.width : size.width,
                  _from.dy < start.center.dy ? -size.height : size.height,
                ),
          );
        case _Drag.turn:
          final d = point - start.center;
          final degrees =
              (math.atan2(d.dy, d.dx) * 180 / math.pi + 90 + 180) % 360 - 180;
          final step = HardwareKeyboard.instance.isShiftPressed
              ? SignaturePlacementOverlay.step
              : 1;
          _tilt = (degrees / step).roundToDouble() * step;
      }
    });
  }

  void _onPanEnd() {
    if (_drag != _Drag.turn) _keepField();
    setState(() => _drag = null);
  }

  /// A draft moved out of its field no longer signs it.
  void _keepField() {
    final field = _field;
    final box = _box;
    if (field == null || box == null) return;
    unawaited(() async {
      final view = ref.read(viewerProvider);
      if (view == null) return;
      final handle = view.document.pageHandle(_page ?? -1);
      final FormInfo form;
      try {
        form = await ref
            .read(engineServiceProvider)
            .formFields(view.document.id);
      } on EngineException {
        return;
      }
      final still = form.fields.any(
        (f) =>
            f.name == field &&
            f.widgets.any(
              (w) => w.page == handle && w.rect.contains(box.center),
            ),
      );
      if (!still && mounted && _field == field) setState(() => _field = null);
    }());
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final signature = ref.read(signaturePlacementProvider);
    if (signature == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_box != null) {
        _clear();
      } else {
        ref.read(signaturePlacementProvider.notifier).end();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_box != null) {
        _commit(signature);
        return KeyEventResult.handled;
      }
      final view = ref.read(viewerProvider);
      final page = view?.currentPage ?? 0;
      final info = view?.document.pages.elementAtOrNull(page);
      if (view == null || info == null) return KeyEventResult.ignored;
      unawaited(
        _start(signature, view, page, Offset(info.width / 2, info.height / 2)),
      );
      return KeyEventResult.handled;
    }
    final box = _box;
    if (box == null) return KeyEventResult.ignored;
    final by = HardwareKeyboard.instance.isShiftPressed ? 10.0 : 1.0;
    final nudge = switch (key) {
      LogicalKeyboardKey.arrowLeft => Offset(-by, 0),
      LogicalKeyboardKey.arrowRight => Offset(by, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -by),
      LogicalKeyboardKey.arrowDown => Offset(0, by),
      _ => null,
    };
    if (nudge == null) return KeyEventResult.ignored;
    setState(() => _box = box.shift(nudge));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(viewerProvider);
    final signature = ref.watch(signaturePlacementProvider);
    final region = ref.watch(regionProvider);
    // Another choice, or leaving Fill & Sign, places the draft first.
    ref
      ..listen(signaturePlacementProvider, (before, after) {
        if (before != null && after != before && _box != null) {
          _commit(before, end: false);
        }
      })
      ..listen(shellModeProvider, (_, mode) {
        if (mode != FermanMode.sign && signature != null && _box != null) {
          _commit(signature);
        }
      });
    if (view == null || signature == null) return const SizedBox.shrink();
    final page = _page;
    final box = _box;
    final pageRect = page == null
        ? null
        : view.placement.rects.elementAtOrNull(page)?.shift(-view.offset);
    final accent = theme.colors.accent;
    final format = RegionFormat.forRegion(region.region);
    final tilt = format.integer(_tilt.round()).replaceFirst('-', '\u2212');
    final size = box == null
        ? ''
        : format.dimensions(
            box.width,
            box.height,
            region.lengthUnit,
            // Whole millimetres, as a5-3d writes them.
            maxFractionDigits: region.lengthUnit == LengthUnit.millimetre
                ? 0
                : null,
          );
    return Semantics(
      container: true,
      label: l10n.placeSignatureHint,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: (_, event) => _onKey(event),
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: Listener(
            onPointerUp: (_) => _focus.requestFocus(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: (details) => _onTapUp(view, details),
              onPanStart: (details) => _onPanStart(view, details),
              onPanUpdate: (details) => _onPanUpdate(view, details),
              onPanEnd: (_) => _onPanEnd(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const SizedBox.expand(),
                  if (pageRect != null && box != null) ...[
                    PositionedDirectional(
                      start: pageRect.left + box.left * view.scale,
                      top: pageRect.top + box.top * view.scale,
                      width: box.width * view.scale,
                      height: box.height * view.scale,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: _tilt * math.pi / 180,
                          child: _Draft(
                            signature: signature,
                            color: accent,
                            handle: theme.pageColors.pageBg,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: pageRect.left + box.left * view.scale,
                      top:
                          pageRect.top +
                          box.bottom * view.scale +
                          theme.space.space2,
                      child: IgnorePointer(
                        child: Container(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: theme.space.space1_5,
                            vertical: theme.space.space0_5,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(
                              theme.radius.radiusXs,
                            ),
                          ),
                          child: Text(
                            '$size · $tilt°',
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.textOnAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The draft: its ink fitted into the frame, the four corner handles and the
/// round handle on its stem (a5-3d).
class _Draft extends StatelessWidget {
  const new({
    required this.signature,
    required this.color,
    required this.handle,
  });

  final SavedSignature signature;
  final Color color;
  final Color handle;

  @override
  Widget build(BuildContext context) {
    const corner = SignaturePlacementOverlay.corner;
    const frame = SignaturePlacementOverlay.frame;
    const knob = SignaturePlacementOverlay.knob;
    final square = Container(
      width: corner,
      height: corner,
      decoration: BoxDecoration(
        color: handle,
        border: Border.all(color: color, width: frame),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: frame),
              ),
              child: Center(
                child: FittedBox(
                  child: SignaturePreview(
                    signature: signature,
                    height:
                        constraints.maxHeight *
                        SignaturePlacementOverlay.inkShare,
                  ),
                ),
              ),
            ),
          ),
          for (final (x, y) in const [
            (0.0, 0.0),
            (1.0, 0.0),
            (0.0, 1.0),
            (1.0, 1.0),
          ])
            PositionedDirectional(
              start: x * constraints.maxWidth - corner / 2,
              top: y * constraints.maxHeight - corner / 2,
              child: square,
            ),
          PositionedDirectional(
            start: constraints.maxWidth / 2 - frame / 2,
            top: -SignaturePlacementOverlay.knobReach + knob / 2,
            width: frame,
            height: SignaturePlacementOverlay.stem,
            child: ColoredBox(color: color),
          ),
          PositionedDirectional(
            start: constraints.maxWidth / 2 - knob / 2,
            top: -SignaturePlacementOverlay.knobReach - knob / 2,
            child: Container(
              width: knob,
              height: knob,
              decoration: BoxDecoration(
                color: handle,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: frame),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
