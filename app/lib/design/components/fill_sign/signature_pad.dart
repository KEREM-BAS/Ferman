import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/forms/checkbox.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/components/navigation/segmented_control.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// How a signature is made in a [SignaturePad].
enum SignatureMode {
  /// Drawn with a mouse, trackpad, pen or finger.
  draw,

  /// The name typed, set in the signature face.
  type,

  /// A photo or scan of a signature on paper.
  image,
}

/// What a [SignaturePad] holds, reported through its `onChanged`: the
/// design-system `SignatureValue`. Strokes are data, never an image.
@immutable
class SignatureValue {
  /// A value made in [mode] with [ink].
  const new({
    required this.mode,
    required this.ink,
    this.strokes = const [],
    this.text = '',
    this.isEmpty = true,
  });

  /// How the signature was made.
  final SignatureMode mode;

  /// The drawn strokes, each a list of points in the drawing area's
  /// logical pixels (rounded to 0.1, as the bundle does).
  final List<List<Offset>> strokes;

  /// The typed name.
  final String text;

  /// The ink colour.
  final Color ink;

  /// Whether nothing is drawn (draw mode) or typed (the other modes).
  final bool isEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! SignatureValue ||
        other.mode != mode ||
        other.text != text ||
        other.ink != ink ||
        other.isEmpty != isEmpty ||
        other.strokes.length != strokes.length) {
      return false;
    }
    for (var i = 0; i < strokes.length; i++) {
      if (!listEquals(other.strokes[i], strokes[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    mode,
    text,
    ink,
    isEmpty,
    Object.hashAll(strokes.map(Object.hashAll)),
  );

  @override
  String toString() =>
      'SignatureValue($mode, ${strokes.length} strokes, empty: $isEmpty)';
}

/// The localized texts of a [SignaturePad] (the bundle's English copy).
/// Not a design-system type.
@immutable
class SignaturePadLabels {
  /// Creates the texts.
  const new({
    required this.method,
    required this.draw,
    required this.type,
    required this.image,
    required this.drawingArea,
    required this.typeName,
    required this.namePlaceholder,
    required this.drawHint,
    required this.typeHint,
    required this.imageHint,
    required this.chooseImage,
    required this.inkColor,
    required this.black,
    required this.blue,
    required this.clear,
    required this.saveOnDevice,
  });

  /// The mode group's name, "Signature method".
  final String method;

  /// The draw mode, "Draw".
  final String draw;

  /// The type mode, "Type".
  final String type;

  /// The image mode, "Image".
  final String image;

  /// The drawing area's name, "Signature drawing area. Draw with a mouse,
  /// trackpad, pen or finger."
  final String drawingArea;

  /// The typed name field's name, "Type your name".
  final String typeName;

  /// Its placeholder, "Your name".
  final String namePlaceholder;

  /// The empty drawing area's hint, "Sign above the line".
  final String drawHint;

  /// The empty name field's hint, "Type your name above the line".
  final String typeHint;

  /// The image mode's text, "Drop a photo or scan of your signature.
  /// Ferman removes the background."
  final String imageHint;

  /// The image mode's button, "Choose image…".
  final String chooseImage;

  /// The ink group's name, "Ink color".
  final String inkColor;

  /// The black ink's name, "Black".
  final String black;

  /// The blue ink's name, "Blue".
  final String blue;

  /// The Clear button, "Clear".
  final String clear;

  /// The checkbox, "Save on this device".
  final String saveOnDevice;
}

/// Signature capture, the design-system `SignaturePad` component
/// (`components/fill-sign/fill-sign.css`, `.fm-sigpad`;
/// `SignaturePad.jsx`): draw, type or image, two ink colours, Clear and
/// "Save on this device".
///
/// From the top, 12 px apart: the [mode] segmented control (Draw, Type,
/// Image), a 188 px drawing area on the page colour with a signature line
/// and its ×, and a bar with the two ink swatches (black `#1F1D1A`, blue
/// `#1A3170`), Clear (disabled while empty) and the [saveForLater]
/// checkbox.
///
/// - **Draw:** pointer strokes in [ink], smoothed through quadratic
///   midpoints at a 2.2 px width; "Sign above the line" while empty. The
///   strokes are kept as data ([initialStrokes] to start with) and passed
///   out through [onChanged] when a stroke ends; nothing is turned into an
///   image. Ctrl+Z (⌘Z) in the focused area removes the last stroke
///   (`a5-3b` board note).
/// - **Type:** the name ([initialName] to start with) in the 40 px italic
///   signature face, in [ink]; "Type your name above the line" while empty.
/// - **Image:** the dashed drop box with "Choose image…". Picking or
///   dropping an image needs a file picker and drag and drop, neither in
///   M1, so the button is disabled with "Available in a future version".
///
/// The pad is controlled for [mode] ([onModeChanged]), [ink]
/// ([onInkChanged]) and [saveForLater] ([onSaveForLaterChanged]); the
/// strokes and the typed name live in the pad and are reported through
/// [onChanged] (after a stroke, an edit, Clear or an undo).
///
/// The drawing area is on the page colour in both themes; the controls
/// follow the theme. Every text comes from [labels].
///
/// **Keyboard:** ArrowLeft and ArrowRight move between modes (the segmented
/// control) and between inks (radio group); Tab reaches the drawing area,
/// which draws with a pointer only (Type is the keyboard alternative).
///
/// For screen readers it is a group with the "Signature method" and "Ink
/// color" radio groups and the drawing area named
/// [SignaturePadLabels.drawingArea].
class SignaturePad extends StatefulWidget {
  /// Creates a signature pad.
  const new({
    required this.labels,
    super.key,
    this.mode = SignatureMode.draw,
    this.onModeChanged,
    this.initialName = '',
    this.ink = blackInk,
    this.onInkChanged,
    this.saveForLater = true,
    this.onSaveForLaterChanged,
    this.onChanged,
    this.initialStrokes = const [],
  });

  /// `INKS[0]`, Black: `#1F1D1A` (`--paper-900`, `--annot-ink`).
  static const Color blackInk = Color(0xFF1F1D1A);

  /// `INKS[1]`, Blue: `#1A3170` (`--ink-800`).
  static const Color blueInk = Color(0xFF1A3170);

  /// `.fm-sigpad__area` `height: 188px`.
  static const double areaHeight = 188;

  /// `.fm-sigpad__line` `inset-inline: 28px`; also the ×'s start inset.
  static const double lineInset = 28;

  /// `.fm-sigpad__line` `bottom: 48px`.
  static const double lineBottom = 48;

  /// `.fm-sigpad__x` `bottom: 54px`.
  static const double crossBottom = 54;

  /// `.fm-sigpad__x` `font: 400 18px/1`.
  static const double crossFontSize = 18;

  /// The signature line's mark (`×`): a symbol, not copy.
  static const String cross = '×';

  /// `.fm-sigpad__hint` `bottom: 20px`.
  static const double hintBottom = 20;

  /// `.fm-sigpad__typed` `inset-inline: 44px 28px`, start.
  static const double typedStart = 44;

  /// `.fm-sigpad__typed` `bottom: 52px`.
  static const double typedBottom = 52;

  /// `.fm-sigpad__typed` `font: italic 400 40px/1.1 var(--font-brand)`.
  static const double typedFontSize = 40;

  /// `.fm-sigpad__typed` line height.
  static const double typedHeight = 1.1;

  /// `.fm-sigpad__image` `inset: 12px`.
  static const double imageInset = 12;

  /// `.fm-sigpad__image` `border: 1.5px dashed`.
  static const double imageBorder = 1.5;

  /// `SignaturePad.jsx` image glyph size.
  static const double imageIconSize = 20;

  /// The 1.5 px dashes as Chromium draws them.
  static const double dashLength = 3;

  /// The gaps between those dashes.
  static const double dashGap = 2;

  /// `SignaturePad.jsx` `strokeWidth="2.2"`.
  static const double strokeWidth = 2.2;

  /// `.fm-annot-color` `width` and `height: 18px`.
  static const double swatchSize = 18;

  /// `.fm-annot-color` `box-shadow: inset 0 0 0 1px rgba(0,0,0,.16)`.
  static const Color swatchRingLight = Color(0x29000000);

  /// `[data-theme="dark"] .fm-annot-color` ring `rgba(255,255,255,.28)`.
  static const Color swatchRingDark = Color(0x47FFFFFF);

  /// How the signature is made.
  final SignatureMode mode;

  /// Called with the mode the user picks; null makes the modes inert.
  final ValueChanged<SignatureMode>? onModeChanged;

  /// The typed name to start with (the bundle's `name`).
  final String initialName;

  /// The ink colour: [blackInk] or [blueInk].
  final Color ink;

  /// Called with the ink the user picks; null makes the inks inert. Not a
  /// design-system prop.
  final ValueChanged<Color>? onInkChanged;

  /// Whether "Save on this device" is checked.
  final bool saveForLater;

  /// Called when "Save on this device" is toggled; null disables it. Not a
  /// design-system prop.
  final ValueChanged<bool>? onSaveForLaterChanged;

  /// Called with the signature after each stroke, edit, Clear or undo.
  final ValueChanged<SignatureValue>? onChanged;

  /// The strokes to start with.
  final List<List<Offset>> initialStrokes;

  /// The localized texts. Not a design-system prop.
  final SignaturePadLabels labels;

  @override
  State<SignaturePad> createState() => _SignaturePadState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<SignatureMode>(
          'mode',
          mode,
          defaultValue: SignatureMode.draw,
        ),
      )
      ..add(ColorProperty('ink', ink, defaultValue: blackInk))
      ..add(FlagProperty('saveForLater', value: saveForLater, ifTrue: 'save'))
      ..add(IntProperty('initialStrokes', initialStrokes.length));
  }
}

class _UndoIntent extends Intent {
  const new();
}

class _SignaturePadState extends State<SignaturePad> {
  late final List<List<Offset>> _strokes = [
    for (final stroke in widget.initialStrokes) [...stroke],
  ];
  late final TextEditingController _typed = TextEditingController(
    text: widget.initialName,
  )..addListener(_onTyped);
  final FocusNode _area = FocusNode(debugLabel: 'SignaturePad area');
  final FocusNode _typedNode = FocusNode(debugLabel: 'SignaturePad name');
  final List<FocusNode> _inkNodes = [
    FocusNode(debugLabel: 'SignaturePad black'),
    FocusNode(debugLabel: 'SignaturePad blue'),
  ];
  bool _drawing = false;
  bool _areaFocusVisible = false;
  String _lastTyped = '';

  static const List<Color> _inks = [
    SignaturePad.blackInk,
    SignaturePad.blueInk,
  ];

  static const Map<ShortcutActivator, Intent> _areaShortcuts = {
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
  };

  @override
  void initState() {
    super.initState();
    _lastTyped = _typed.text;
  }

  @override
  void dispose() {
    _typed
      ..removeListener(_onTyped)
      ..dispose();
    _area.dispose();
    _typedNode.dispose();
    for (final node in _inkNodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _isEmpty => switch (widget.mode) {
    SignatureMode.draw => _strokes.isEmpty,
    SignatureMode.type => _typed.text.isEmpty,
    SignatureMode.image => true,
  };

  void _emit() {
    widget.onChanged?.call(
      SignatureValue(
        mode: widget.mode,
        strokes: List.unmodifiable([
          for (final stroke in _strokes) List<Offset>.unmodifiable(stroke),
        ]),
        text: _typed.text,
        ink: widget.ink,
        // The bundle: draw mode is empty without strokes, the others without
        // a typed name.
        isEmpty: widget.mode == SignatureMode.draw
            ? _strokes.isEmpty
            : _typed.text.isEmpty,
      ),
    );
  }

  void _onTyped() {
    if (_typed.text == _lastTyped) return;
    _lastTyped = _typed.text;
    setState(() {});
    _emit();
  }

  static Offset _round(Offset point) => Offset(
    (point.dx * 10).roundToDouble() / 10,
    (point.dy * 10).roundToDouble() / 10,
  );

  void _down(PointerDownEvent event) {
    if (widget.mode != SignatureMode.draw) return;
    setState(() {
      _drawing = true;
      _strokes.add([_round(event.localPosition)]);
    });
  }

  void _move(PointerMoveEvent event) {
    if (!_drawing) return;
    setState(() => _strokes.last.add(_round(event.localPosition)));
  }

  void _up() {
    if (!_drawing) return;
    _drawing = false;
    _emit();
  }

  void _clear() {
    setState(_strokes.clear);
    _lastTyped = '';
    _typed.clear();
    _emit();
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(_strokes.removeLast);
    _emit();
  }

  KeyEventResult _onInkKey(FocusNode _, KeyEvent event) {
    final step = RovingFocus.stepFor(event, Directionality.of(context));
    final onInkChanged = widget.onInkChanged;
    if (step == null || onInkChanged == null) return KeyEventResult.ignored;
    final from = _inkNodes.indexWhere((node) => node.hasFocus);
    if (from < 0) return KeyEventResult.ignored;
    final to = RovingFocus.target(from, _inks.length, step, (_) => true);
    if (to == null) return KeyEventResult.handled;
    _inkNodes[to].requestFocus();
    onInkChanged(_inks[to]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final labels = widget.labels;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          SegmentedControl<SignatureMode>(
            semanticLabel: labels.method,
            value: widget.mode,
            onChanged: widget.onModeChanged,
            options: [
              SegmentOption(
                value: SignatureMode.draw,
                label: labels.draw,
                icon: IconName.penLine,
              ),
              SegmentOption(
                value: SignatureMode.type,
                label: labels.type,
                icon: IconName.type,
              ),
              SegmentOption(
                value: SignatureMode.image,
                label: labels.image,
                icon: IconName.image,
              ),
            ],
          ),
          _drawingArea(context, theme),
          _bar(theme),
        ],
      ),
    );
  }

  Widget _drawingArea(BuildContext context, FermanTheme theme) {
    final labels = widget.labels;
    final ramps = theme.ramps;
    final mode = widget.mode;
    final draw = mode == SignatureMode.draw;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusMd));
    final hint = switch (mode) {
      SignatureMode.draw => labels.drawHint,
      SignatureMode.type => labels.typeHint,
      SignatureMode.image => null,
    };
    final caption = theme.typography.caption;
    final layers = <Widget>[
      PositionedDirectional(
        start: SignaturePad.lineInset,
        end: SignaturePad.lineInset,
        bottom: SignaturePad.lineBottom,
        child: Container(
          key: const ValueKey<String>('SignaturePad.line'),
          height: theme.border.borderWidth,
          color: ramps.paper300,
        ),
      ),
      PositionedDirectional(
        start: SignaturePad.lineInset,
        bottom: SignaturePad.crossBottom,
        child: ExcludeSemantics(
          child: Text(
            SignaturePad.cross,
            style: theme.typography.body.copyWith(
              fontSize: SignaturePad.crossFontSize,
              height: 1,
              fontWeight: theme.typeScale.weightRegular,
              color: ramps.paper400,
            ),
          ),
        ),
      ),
      if (draw)
        Positioned.fill(
          child: CustomPaint(
            key: const ValueKey<String>('SignaturePad.strokes'),
            painter: SignatureStrokesPainter(
              strokes: _strokes,
              color: widget.ink,
            ),
          ),
        ),
      if (mode == SignatureMode.type)
        PositionedDirectional(
          start: SignaturePad.typedStart,
          end: SignaturePad.lineInset,
          bottom: SignaturePad.typedBottom,
          child: MergeSemantics(
            child: Semantics(
              label: labels.typeName,
              child: FieldInput(
                controller: _typed,
                focusNode: _typedNode,
                autofocus: true,
                placeholder: labels.namePlaceholder,
                placeholderColor: ramps.paper300,
                style: theme.typography.body.copyWith(
                  fontFamily: theme.typeScale.fontBrand.family,
                  fontStyle: FontStyle.italic,
                  fontSize: SignaturePad.typedFontSize,
                  height: SignaturePad.typedHeight,
                  fontWeight: theme.typeScale.weightRegular,
                  color: widget.ink,
                ),
              ),
            ),
          ),
        ),
      if (mode == SignatureMode.image)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(SignaturePad.imageInset),
            child: CustomPaint(
              key: const ValueKey<String>('SignaturePad.image'),
              painter: _DashedRoundedPainter(
                color: ramps.paper300,
                radius: theme.radius.radiusSm,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.space.space2,
                  children: [
                    Icon(
                      IconName.image,
                      size: SignaturePad.imageIconSize,
                      color: ramps.paper600,
                    ),
                    Text(
                      labels.imageHint,
                      textAlign: TextAlign.center,
                      style: caption.copyWith(color: ramps.paper600),
                    ),
                    Button(
                      size: ButtonSize.sm,
                      icon: IconName.folderOpen,
                      disabled: true,
                      disabledReason: futureVersionReason(context),
                      onPressed: () {},
                      child: Text(labels.chooseImage),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (hint != null && _isEmpty)
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: SignaturePad.hintBottom,
          child: IgnorePointer(
            child: Text(
              hint,
              key: const ValueKey<String>('SignaturePad.hint'),
              textAlign: TextAlign.center,
              style: caption.copyWith(color: ramps.paper500),
            ),
          ),
        ),
    ];
    final forced = FermanForcedStates.of(context).contains(WidgetState.focused);
    Widget area = Container(
      key: const ValueKey<String>('SignaturePad.area'),
      height: SignaturePad.areaHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.pageColors.pageBg,
        borderRadius: radius,
        border: Border.all(
          color: theme.colors.borderDefault,
          width: theme.border.borderWidth,
        ),
      ),
      child: Stack(children: layers),
    );
    area = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: area,
    );
    area = FocusRing(
      visible: draw && (_areaFocusVisible || forced),
      borderRadius: radius,
      child: area,
    );
    return FocusableActionDetector(
      focusNode: _area,
      enabled: draw,
      includeFocusSemantics: false,
      shortcuts: _areaShortcuts,
      actions: {
        _UndoIntent: CallbackAction<_UndoIntent>(
          onInvoke: (_) {
            _undo();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) =>
          setState(() => _areaFocusVisible = value),
      mouseCursor: draw ? SystemMouseCursors.precise : MouseCursor.defer,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        focusable: draw ? true : null,
        focused: draw ? _area.hasFocus : null,
        label: draw ? labels.drawingArea : null,
        child: area,
      ),
    );
  }

  Widget _bar(FermanTheme theme) {
    final labels = widget.labels;
    final names = [labels.black, labels.blue];
    final checkedIndex = _inks.indexOf(widget.ink);
    final stop = checkedIndex < 0 ? 0 : checkedIndex;
    return Row(
      spacing: theme.space.space2,
      children: [
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onInkKey,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            role: SemanticsRole.radioGroup,
            label: labels.inkColor,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.space1_5,
              children: [
                for (var i = 0; i < _inks.length; i++)
                  _InkSwatch(
                    color: _inks[i],
                    name: names[i],
                    checked: i == checkedIndex,
                    focusNode: _inkNodes[i]..skipTraversal = i != stop,
                    onPressed: widget.onInkChanged == null
                        ? null
                        : () => widget.onInkChanged!(_inks[i]),
                  ),
              ],
            ),
          ),
        ),
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          icon: IconName.eraser,
          disabled: _isEmpty,
          onPressed: _clear,
          child: Text(labels.clear),
        ),
        const Spacer(),
        Checkbox(
          checked: widget.saveForLater,
          label: labels.saveOnDevice,
          onChanged: widget.onSaveForLaterChanged,
        ),
      ],
    );
  }
}

/// An ink swatch (`.fm-annot-color`): an 18 px circle in [color] with a
/// hairline, a ring on hover, the checked double ring and the focus ring.
class _InkSwatch extends StatelessWidget {
  const new({
    required this.color,
    required this.name,
    required this.checked,
    required this.focusNode,
    required this.onPressed,
  });

  final Color color;
  final String name;
  final bool checked;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final halo = theme.space.space0_5;
    return FermanInteractive(
      focusNode: focusNode,
      onPressed: onPressed,
      checked: checked,
      inMutuallyExclusiveGroup: true,
      isButton: false,
      semanticLabel: name,
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        final hovered = states.contains(WidgetState.hovered);
        final List<BoxShadow> outside;
        if (focused) {
          outside = FocusRing.outerShadows(theme);
        } else if (checked) {
          // `0 0 0 2px var(--surface-panel), 0 0 0 4px var(--text-primary)`.
          outside = [
            BoxShadow(color: colors.textPrimary, spreadRadius: halo * 2),
            BoxShadow(color: colors.surfacePanel, spreadRadius: halo),
          ];
        } else if (hovered) {
          outside = [BoxShadow(color: colors.borderStrong, spreadRadius: halo)];
        } else {
          outside = const [];
        }
        return Container(
          width: SignaturePad.swatchSize,
          height: SignaturePad.swatchSize,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: outside),
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.isDark
                  ? SignaturePad.swatchRingDark
                  : SignaturePad.swatchRingLight,
              width: theme.border.borderWidth,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}

/// Paints signature strokes as `SignaturePad.jsx` does: each stroke a path
/// through quadratic curves to the midpoints between its points, in
/// [color] at [SignaturePad.strokeWidth] with round caps and joins.
class SignatureStrokesPainter extends CustomPainter {
  /// Paints [strokes] in [color].
  const new({required this.strokes, required this.color});

  /// The strokes, each a list of points.
  final List<List<Offset>> strokes;

  /// The ink.
  final Color color;

  /// The path of one stroke (the bundle's `toPath`).
  static Path pathOf(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length < 3) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }
    for (var i = 1; i < points.length - 1; i++) {
      final mid = (points[i] + points[i + 1]) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = SignaturePad.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final stroke in strokes) {
      canvas.drawPath(pathOf(stroke), paint);
    }
  }

  // The strokes list is mutated in place while drawing.
  @override
  bool shouldRepaint(SignatureStrokesPainter oldDelegate) => true;
}

/// Paints the image box's dashed border: [SignaturePad.imageBorder] wide,
/// inside the box, with [radius] corners.
class _DashedRoundedPainter extends CustomPainter {
  const new({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const width = SignaturePad.imageBorder;
    final box = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(math.max(0, radius - width / 2)),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    for (final metric in (Path()..addRRect(box)).computeMetrics()) {
      for (
        var at = 0.0;
        at < metric.length;
        at += SignaturePad.dashLength + SignaturePad.dashGap
      ) {
        canvas.drawPath(
          metric.extractPath(
            at,
            math.min(at + SignaturePad.dashLength, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
