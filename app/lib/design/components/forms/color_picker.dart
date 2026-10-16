import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A colour trigger that opens a popover of document colours, standard
/// swatches, a hex field and a page eyedropper, the design-system
/// `ColorPicker` component (`components/forms/ColorPicker.jsx`,
/// `.fm-colortrigger`, `.fm-colorpop`).
///
/// The trigger is a [Field] box of [size] with [label] above: a 16 px chip
/// of [value] (`.fm-chip`; struck through in red for none), the colour as
/// an upper-case hex code (or [noneLabel], upper-cased by the casing rules
/// of the UI language: the CSS `text-transform: uppercase`) and a
/// `chevron-down`. Keyboard focus gives it the outer focus ring
/// (`.fm-colortrigger:focus-visible`).
///
/// Enter, Space or a click toggle the popover (232 px, `.fm-colorpop`): an
/// "In this document" section of [documentColors] when there are any, a
/// "Standard" section of [swatches] (the design's 16 colours by default)
/// led by a none swatch when [allowNone], then the hex field and the
/// eyedropper slot. Swatches are 20 px Tab stops (as in the bundle) with a
/// strong ring under the pointer, the focus ring under keyboard focus and
/// an accent ring when selected. Opening the popover with Enter or Space
/// (or through [open] or [initiallyOpen]) moves focus to the selected
/// swatch (the first one when none is); a click opens it with focus on the
/// popover itself, so neither a swatch nor the trigger shows the focus
/// ring (G22), and Tab moves into the swatches. The popover is a focus
/// scope of its own, so Tab and Shift+Tab cycle through the swatches, the
/// hex field and the eyedropper and never reach the controls it covers.
/// The hex field commits a six-digit code on Enter or when focus leaves.
/// Escape closes the popover and returns focus to the trigger; a click
/// outside closes it too, and returns focus to the trigger unless a click
/// opened it.
///
/// The open state is [open] when given (with [onOpenChanged] reporting
/// requests), else local, starting at [initiallyOpen]. The colour is
/// controlled: a pick calls [onChanged] (null for none).
///
/// Every text is a parameter: [noneLabel], [documentColorsLabel],
/// [standardColorsLabel], [noColorLabel], [hexLabel], [hexSemanticLabel]
/// and [dialogLabel]; a null section label hides the heading. The
/// eyedropper ("Pick a color from the page", an IconButton) needs the
/// engine (M3) and comes in through [eyedropper].
///
/// For screen readers the trigger is a button named by [label] whose value
/// is the colour, expanded while the popover is open; the popover is a
/// dialog named by [dialogLabel]; swatches are buttons named by their hex
/// code, selected when they match.
class ColorPicker extends StatefulWidget {
  /// Creates a colour picker.
  const new({
    super.key,
    this.label,
    this.value,
    this.documentColors = const [],
    this.swatches = standardSwatches,
    this.allowNone = false,
    this.open,
    this.initiallyOpen = false,
    this.onOpenChanged,
    this.onChanged,
    this.size = FieldSize.sm,
    this.disabled = false,
    this.disabledReason,
    this.noneLabel,
    this.documentColorsLabel,
    this.standardColorsLabel,
    this.noColorLabel,
    this.hexLabel,
    this.hexSemanticLabel,
    this.dialogLabel,
    this.eyedropper,
    this.focusNode,
  });

  /// The bundle's `STANDARD` palette, 16 colours of document ink: greys
  /// and white, the accent ink, teal, green, amber, red, seal, violet and
  /// the four highlighter colours. They are page colours, the same in both
  /// themes; teal `#0F7F72` and violet `#6B3FA0` have no design token.
  static const List<Color> standardSwatches = [
    FermanRampTokens.paper900,
    FermanRampTokens.paper700,
    FermanRampTokens.paper500,
    FermanRampTokens.paper300,
    FermanRampTokens.paper0,
    FermanRampTokens.ink600,
    Color(0xFF0F7F72),
    FermanRampTokens.green600,
    FermanRampTokens.amber500,
    FermanRampTokens.red600,
    FermanRampTokens.seal600,
    Color(0xFF6B3FA0),
    FermanRampTokens.annotYellow,
    FermanRampTokens.annotGreen,
    FermanRampTokens.annotBlue,
    FermanRampTokens.annotPink,
  ];

  /// `.fm-colorpop` `width`.
  static const double popoverWidth = 232;

  /// `.fm-chip` `width` and `height`.
  static const double chipSize = 16;

  /// `.fm-swatch` `width` and `height`.
  static const double swatchSize = 20;

  /// `.fm-chip` and `.fm-swatch` `border-radius`.
  static const double swatchRadius = 3;

  /// `.fm-swatches` `gap`.
  static const double swatchGap = 6;

  /// `.fm-chip` `box-shadow: inset 0 0 0 1px rgba(0,0,0,.14)`.
  static const Color chipEdgeLight = Color(0x24000000);

  /// `[data-theme="dark"] .fm-chip, [data-theme="dark"] .fm-swatch`
  /// `rgba(255,255,255,.24)`: the trigger's chip and a swatch at rest in
  /// dark. A hovered or selected swatch keeps [chipEdgeLight] in dark too
  /// (`.fm-swatch:hover` and `[aria-pressed]` come later at the same
  /// specificity).
  static const Color chipEdgeDark = Color(0x3DFFFFFF);

  /// The label above the trigger; null shows none.
  final String? label;

  /// The colour; null is "none" (with [allowNone]).
  final Color? value;

  /// The colours used in the document, shown first; empty hides the
  /// section.
  final List<Color> documentColors;

  /// The standard swatches.
  final List<Color> swatches;

  /// Whether a "no colour" swatch leads the standard swatches.
  final bool allowNone;

  /// Whether the popover is open; null keeps the state locally.
  final bool? open;

  /// Whether a locally kept popover starts open (the DS `defaultOpen`).
  final bool initiallyOpen;

  /// Called when the popover asks to open or close.
  final ValueChanged<bool>? onOpenChanged;

  /// Called with the picked colour, null for none; null disables the
  /// picker.
  final ValueChanged<Color?>? onChanged;

  /// The height and padding of the trigger.
  final FieldSize size;

  /// Whether the picker is disabled.
  final bool disabled;

  /// Why the picker is disabled (G10). Not a design-system prop.
  final String? disabledReason;

  /// The trigger text for no colour (the bundle's "None").
  final String? noneLabel;

  /// The heading of the document colours ("In this document").
  final String? documentColorsLabel;

  /// The heading of the standard swatches ("Standard").
  final String? standardColorsLabel;

  /// The accessible name of the none swatch ("No color").
  final String? noColorLabel;

  /// The visible label in the hex field ("Hex").
  final String? hexLabel;

  /// The accessible name of the hex field ("Hex color").
  final String? hexSemanticLabel;

  /// The accessible name of the popover ("Choose color").
  final String? dialogLabel;

  /// The eyedropper button after the hex field (an IconButton with
  /// `pipette`, disabled until M3); null shows none.
  final Widget? eyedropper;

  /// The focus node of the trigger; one is created when null.
  final FocusNode? focusNode;

  /// [color] as an upper-case `#RRGGBB` code (the CSS `text-transform:
  /// uppercase` of `.fm-colortrigger__value`).
  static String hexOf(Color color) {
    const digits = '0123456789ABCDEF';
    final rgb = color.toARGB32() & 0xFFFFFF;
    final buffer = StringBuffer('#');
    for (var shift = 20; shift >= 0; shift -= 4) {
      buffer.write(digits[(rgb >> shift) & 0xF]);
    }
    return buffer.toString();
  }

  /// The colour of a six-digit hex code with or without `#`, else null.
  static Color? parseHex(String text) {
    final match = _hex.firstMatch(text.trim());
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  static final RegExp _hex = RegExp(r'^#?([0-9a-fA-F]{6})$');

  @override
  State<ColorPicker> createState() => _ColorPickerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(ColorProperty('value', value, defaultValue: null))
      ..add(IterableProperty<Color>('documentColors', documentColors))
      ..add(FlagProperty('allowNone', value: allowNone, ifTrue: 'allows none'))
      ..add(
        FlagProperty('open', value: open, ifTrue: 'open', ifFalse: 'closed'),
      )
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.sm))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'));
  }
}

class _ColorPickerState extends State<ColorPicker> {
  late bool _localOpen = widget.initiallyOpen;
  FocusNode? _ownNode;
  final TextEditingController _hex = TextEditingController();
  final FocusNode _hexNode = FocusNode(debugLabel: 'ColorPicker hex');
  bool _hexDraft = false;

  /// The popover's own focus scope (Tab cycles inside it).
  final FocusScopeNode _popoverScope = FocusScopeNode(
    debugLabel: 'ColorPicker popover',
  );

  /// Whether a click (or a screen reader's tap) on the trigger opened the
  /// popover: focus then goes to the popover itself, not to a swatch.
  bool _pointerOpened = false;

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'ColorPicker'));

  bool get _open => _enabled && (widget.open ?? _localOpen);

  bool get _enabled => !widget.disabled && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _hex.text = _hexText();
    _hexNode.addListener(() {
      if (!_hexNode.hasFocus) _commitHex();
    });
  }

  @override
  void didUpdateWidget(ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hexDraft && oldWidget.value != widget.value) _hex.text = _hexText();
    if (!_open) _pointerOpened = false;
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    _hex.dispose();
    _hexNode.dispose();
    _popoverScope.dispose();
    super.dispose();
  }

  String _hexText() {
    final value = widget.value;
    return value == null ? '' : ColorPicker.hexOf(value);
  }

  void _setOpen(bool open) {
    if (!open) _pointerOpened = false;
    if (widget.open == null) setState(() => _localOpen = open);
    widget.onOpenChanged?.call(open);
  }

  /// The trigger's toggle, by Enter or Space, or by [pointer].
  void _toggle({required bool pointer}) {
    final open = _open;
    if (!open) _pointerOpened = pointer;
    _setOpen(!open);
  }

  /// After a click opened the popover, focus goes to the popover itself
  /// once it is built: the trigger would show the focus ring on desktop.
  void _focusPopover() {
    if (_pointerOpened && !_popoverScope.hasFocus) _popoverScope.requestFocus();
  }

  /// Escape in the popover: it closes and the trigger takes focus.
  void _escape() {
    _setOpen(false);
    _node.requestFocus();
  }

  /// A click outside the popover (or Escape on the trigger): it closes,
  /// and focus returns to the trigger unless a click opened it, so a
  /// pointer that opened and closed it leaves no focus ring (G22).
  void _dismiss() {
    final refocus = !_pointerOpened;
    _setOpen(false);
    if (refocus) _node.requestFocus();
  }

  void _pick(Color? color) {
    widget.onChanged?.call(color);
  }

  void _commitHex() {
    if (!_hexDraft) return;
    _hexDraft = false;
    final color = ColorPicker.parseHex(_hex.text);
    if (color != null) {
      _hex.text = ColorPicker.hexOf(color);
      _pick(color);
    } else {
      _hex.text = _hexText();
    }
  }

  Widget _chip(FermanTheme theme, Color? color) {
    final edge = theme.isDark
        ? ColorPicker.chipEdgeDark
        : ColorPicker.chipEdgeLight;
    const radius = BorderRadius.all(Radius.circular(ColorPicker.swatchRadius));
    return SizedBox.square(
      dimension: ColorPicker.chipSize,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: edge),
        ),
        child: color == null
            ? _NoneFill(theme: theme)
            : DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
      ),
    );
  }

  Widget _trigger(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final value = widget.value;
    final disabled = states.contains(WidgetState.disabled);
    final noneLabel = widget.noneLabel;
    return FieldBox(
      size: widget.size,
      disabled: disabled,
      focused: states.contains(WidgetState.focused),
      hovered: states.contains(WidgetState.hovered),
      focusRingStyle: FocusRingStyle.outer,
      child: Row(
        spacing: FieldBox.contentGap,
        children: [
          _chip(theme, value),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                value == null
                    ? (noneLabel == null
                          ? ''
                          : LocaleCasing.of(context).upper(noneLabel))
                    : ColorPicker.hexOf(value),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: FieldBox.textStyleOf(
                  theme,
                  FieldSize.md,
                  color: disabled ? colors.textDisabled : colors.textPrimary,
                ),
              ),
            ),
          ),
          // `.fm-input > svg { color: var(--icon-secondary) }` in every
          // state.
          Icon(
            IconName.chevronDown,
            size: theme.density.iconSm,
            color: colors.iconSecondary,
          ),
        ],
      ),
    );
  }

  Widget _swatches(FermanTheme theme, List<Widget> children) => Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      theme.space.space2_5,
      theme.space.space0_5,
      theme.space.space2_5,
      theme.space.space1_5,
    ),
    child: Wrap(
      spacing: ColorPicker.swatchGap,
      runSpacing: ColorPicker.swatchGap,
      children: children,
    ),
  );

  bool _isSelected(Color? color) {
    final value = widget.value;
    return color == null
        ? value == null
        : value != null && value.toARGB32() == color.toARGB32();
  }

  Widget _swatch(Color? color, {required String label, bool focus = false}) {
    return _Swatch(
      color: color,
      selected: _isSelected(color),
      semanticLabel: label,
      autofocus: focus,
      onPressed: () => _pick(color),
    );
  }

  Widget _popover(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final documentLabel = widget.documentColorsLabel;
    final standardLabel = widget.standardColorsLabel;
    final hexLabel = widget.hexLabel;
    final eyedropper = widget.eyedropper;
    // The swatch that takes focus when the keyboard opens the popover: the
    // selected one, else the first.
    final all = <Color?>[
      ...widget.documentColors,
      if (widget.allowNone) null,
      ...widget.swatches,
    ];
    final selectedAt = all.indexWhere(_isSelected);
    final focusAt = selectedAt >= 0 ? selectedAt : 0;
    final autofocus = !_pointerOpened;
    var at = -1;
    bool takesFocus() => ++at == focusAt && autofocus;
    return Semantics(
      role: SemanticsRole.dialog,
      explicitChildNodes: true,
      label: widget.dialogLabel,
      child: FocusScope(
        node: _popoverScope,
        child: FocusTraversalGroup(
          child: SizedBox(
            width: ColorPicker.popoverWidth,
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: theme.space.space2_5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.documentColors.isNotEmpty) ...[
                    if (documentLabel != null) PopoverSection(documentLabel),
                    _swatches(theme, [
                      for (final color in widget.documentColors)
                        _swatch(
                          color,
                          label: ColorPicker.hexOf(color),
                          focus: takesFocus(),
                        ),
                    ]),
                  ],
                  if (standardLabel != null) PopoverSection(standardLabel),
                  _swatches(theme, [
                    if (widget.allowNone)
                      _swatch(
                        null,
                        label: widget.noColorLabel ?? '',
                        focus: takesFocus(),
                      ),
                    for (final color in widget.swatches)
                      _swatch(
                        color,
                        label: ColorPicker.hexOf(color),
                        focus: takesFocus(),
                      ),
                  ]),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      theme.space.space2_5,
                      theme.space.space1_5,
                      theme.space.space2_5,
                      0,
                    ),
                    child: Row(
                      spacing: theme.space.space1_5,
                      children: [
                        Expanded(
                          child: MergeSemantics(
                            child: Semantics(
                              label: widget.hexSemanticLabel,
                              child: FieldBox(
                                size: FieldSize.sm,
                                child: Row(
                                  spacing: FieldBox.contentGap,
                                  children: [
                                    if (hexLabel != null)
                                      ExcludeSemantics(
                                        child: Text(
                                          hexLabel,
                                          style: theme.typography.caption
                                              .copyWith(
                                                color: colors.textTertiary,
                                              ),
                                        ),
                                      ),
                                    Expanded(
                                      child: FieldInput(
                                        controller: _hex,
                                        focusNode: _hexNode,
                                        style: FieldBox.textStyleOf(
                                          theme,
                                          FieldSize.sm,
                                          color: colors.textPrimary,
                                        ),
                                        inputFormatters: const [
                                          _HexFormatter(),
                                        ],
                                        onChanged: (_) => _hexDraft = true,
                                        onEditingComplete: _commitHex,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ?eyedropper,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final value = widget.value;
    final open = _open;
    final trigger = FermanInteractive(
      onPressed: _enabled ? () => _toggle(pointer: false) : null,
      onTap: _enabled ? () => _toggle(pointer: true) : null,
      disabled: widget.disabled,
      disabledReason: widget.disabledReason,
      semanticLabel: label,
      focusNode: _node,
      builder: (context, states, _) => Semantics(
        expanded: open,
        value: value == null ? widget.noneLabel : ColorPicker.hexOf(value),
        child: _trigger(context, states),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Field.gap,
      children: [
        if (label != null) Field.labelOf(context, label),
        Popover(
          open: open,
          onDismiss: _dismiss,
          anchor: trigger,
          // Escape in the popover returns focus to the trigger; a click
          // outside (or Escape on the trigger) reaches _dismiss.
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _escape,
            },
            child: _AfterMount(
              onMount: _focusPopover,
              child: _popover(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Runs [onMount] after the frame [child] is first built in: the popover
/// builds its content only once it shows.
class _AfterMount extends StatefulWidget {
  const new({required this.onMount, required this.child});

  final VoidCallback onMount;
  final Widget child;

  @override
  State<_AfterMount> createState() => _AfterMountState();
}

class _AfterMountState extends State<_AfterMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMount();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The struck-through "none" fill (`.fm-chip--none`): the raised surface
/// with a 2 px danger stripe from the top-left to the bottom-right corner.
class _NoneFill extends StatelessWidget {
  const new({required this.theme});

  final FermanTheme theme;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(
      Radius.circular(ColorPicker.swatchRadius),
    ),
    child: CustomPaint(
      painter: _NonePainter(
        background: theme.colors.surfaceRaised,
        stripe: theme.colors.danger,
      ),
    ),
  );
}

class _NonePainter extends CustomPainter {
  const new({required this.background, required this.stripe});

  final Color background;
  final Color stripe;

  /// The stripe's width (`calc(50% ± 1px)`).
  static const double stripeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = background)
      ..drawLine(
        Offset.zero,
        Offset(size.width, size.height),
        Paint()
          ..color = stripe
          ..strokeWidth = stripeWidth,
      );
  }

  @override
  bool shouldRepaint(_NonePainter oldDelegate) =>
      background != oldDelegate.background || stripe != oldDelegate.stripe;
}

/// One 20 px swatch (`.fm-swatch`).
class _Swatch extends StatelessWidget {
  const new({
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
    this.autofocus = false,
  });

  final Color? color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    const radius = BorderRadius.all(Radius.circular(ColorPicker.swatchRadius));
    final fill = color;
    return FermanInteractive(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: semanticLabel,
      autofocus: autofocus,
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        final hovered = states.contains(WidgetState.hovered);
        // forms.css:119 and :121 come after :112 with the same specificity,
        // so a hovered or selected swatch has the dark edge in dark too.
        final edge = theme.isDark && !selected && !hovered
            ? ColorPicker.chipEdgeDark
            : ColorPicker.chipEdgeLight;
        final List<BoxShadow> rings;
        if (focused) {
          rings = FocusRing.outerShadows(theme);
        } else if (selected) {
          rings = [
            BoxShadow(color: colors.accent, spreadRadius: 4),
            BoxShadow(color: colors.surfaceRaised, spreadRadius: 2),
          ];
        } else if (hovered) {
          rings = [BoxShadow(color: colors.borderStrong, spreadRadius: 2)];
        } else {
          rings = const [];
        }
        return Container(
          width: ColorPicker.swatchSize,
          height: ColorPicker.swatchSize,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            boxShadow: rings,
          ),
          foregroundDecoration: focused
              ? null
              : BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: edge),
                ),
          child: fill == null ? _NoneFill(theme: theme) : null,
        );
      },
    );
  }
}

/// Keeps the hex field to `#` and hex digits, at most seven characters,
/// with a–f in upper case (`text-transform: uppercase`).
class _HexFormatter extends TextInputFormatter {
  const new();

  static final RegExp _allowed = RegExp('[^#0-9a-fA-F]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final unit in newValue.text.replaceAll(_allowed, '').codeUnits) {
      // a–f to A–F without the locale-blind String.toUpperCase.
      buffer.writeCharCode(unit >= 0x61 && unit <= 0x66 ? unit - 0x20 : unit);
    }
    var text = buffer.toString();
    if (text.length > 7) text = text.substring(0, 7);
    final offset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
