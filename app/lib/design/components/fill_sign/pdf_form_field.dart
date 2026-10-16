import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The kinds of [PdfFormField] (`PdfFormField.jsx` `type`).
enum PdfFormFieldType {
  /// A single line of text.
  text,

  /// Several lines of text.
  multiline,

  /// A date typed as text, with a calendar glyph.
  date,

  /// A choice from [PdfFormField.options], with a chevron.
  dropdown,

  /// A 16 px box with a check.
  checkbox,

  /// A 16 px circle with a dot.
  radio,

  /// A dashed "Sign here" box, or the signer's name.
  signature,
}

/// The looks of a [PdfFormField] (`.fm-pff--empty`, `--filled`, `--focus`,
/// `--error`, `--readonly`).
enum PdfFormFieldState {
  /// Nothing filled in: the form-field tint and border.
  empty,

  /// Filled in: a fainter tint, so done fields stand out.
  filled,

  /// Focused: white, the focus border and an ink ring.
  focus,

  /// Invalid: a red border, a red ring and the error message.
  error,

  /// Read-only: no box, a dotted line under the value.
  readonly,
}

/// An on-page form field, the design-system `PdfFormField` component
/// (`components/fill-sign/fill-sign.css`, `.fm-pff`; `PdfFormField.jsx`):
/// text, multiline, date, dropdown, checkbox, radio or signature, in the
/// empty, filled, focus, error or read-only look.
///
/// Fields are drawn on the white page, so their colours are the same in
/// both themes (`--form-field-*`). A field is [width] wide (checkboxes and
/// radios are 16 px), with an optional [label] above in 10 px medium text,
/// a red asterisk at its top-end corner when [required], and [error] under
/// it in red with a `circle-alert` (text only under checkboxes and radios,
/// as `a5-2b` draws it). Values are set in the document face (12 px IBM
/// Plex Serif); placeholders in the UI face at 11 px.
///
/// **Look.** [state] forces a look; null derives it: error when [error] is
/// set, filled when there is a [value], [checked] or [signedAs], else
/// empty. On top of that, focus inside the field shows the focus look (it
/// wins over empty and filled, which `fill-sign.css` orders the other way
/// for filled; error and read-only still win), and the pointer strengthens
/// an empty field's border.
///
/// **Editing.** Text, multiline and date fields are editable while
/// [onChanged] is set and the field is not read-only; they report each
/// edit and keep their own text otherwise in step with [value]. A dropdown
/// opens a menu of [options] and reports the choice through [onChanged].
/// Checkboxes, radios and signatures call [onPressed] (toggle, start
/// signing).
///
/// **Keyboard.** Tab and Shift+Tab move between fields; Space toggles a
/// checkbox or radio (not in the bundle); Enter and Space start signing;
/// Enter, Space and ArrowDown open a dropdown.
///
/// For screen readers a field is a text field, a popup button, a checkbox,
/// a radio or a button, named [semanticLabel] or [label] ("Sign here" and
/// `Signed by <name>` come from the caller), required when [required],
/// with [error] as its hint and marked invalid.
class PdfFormField extends StatefulWidget {
  /// Creates a field of [type].
  const new({
    super.key,
    this.type = PdfFormFieldType.text,
    this.state,
    this.value,
    this.placeholder,
    this.label,
    this.required = false,
    this.error,
    this.options = const [],
    this.width = 160,
    this.checked,
    this.signedAs,
    this.onChanged,
    this.onPressed,
    this.signHereLabel,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// `.fm-pff` `gap: 3px` between the label, the box and the message.
  static const double gap = 3;

  /// `.fm-pff__box` `height: 22px`.
  static const double boxHeight = 22;

  /// `.fm-pff__box` `padding: 0 5px`.
  static const double boxPaddingX = 5;

  /// `.fm-pff__box` `border-radius: 2px`.
  static const double boxRadius = 2;

  /// `.fm-pff__box` `font: 400 12px/1 var(--font-doc-sample)`.
  static const double valueFontSize = 12;

  /// `.fm-pff__input::placeholder` `font-size: 11px` (in `#8A857C`,
  /// `--paper-500`, and the UI face).
  static const double placeholderFontSize = 11;

  /// `--form-field-focus` ring: `0 0 0 2px rgba(58, 96, 198, 0.22)`.
  static const Color focusRing = Color(0x383A60C6);

  /// `.fm-pff--focus .fm-pff__box` `background: #FFFFFF`.
  static const Color focusFill = Color(0xFFFFFFFF);

  /// `.fm-pff--filled .fm-pff__box` `background: rgba(58, 96, 198, 0.04)`.
  static const Color filledFill = Color(0x0A3A60C6);

  /// `.fm-pff--filled .fm-pff__box` `border-color: rgba(58, 96, 198, 0.35)`.
  static const Color filledBorder = Color(0x593A60C6);

  /// `.fm-pff--error .fm-pff__box`
  /// `box-shadow: 0 0 0 2px rgba(180, 35, 24, 0.16)`.
  static const Color errorRing = Color(0x29B42318);

  /// `.fm-pff--error .fm-pff__box` `background: rgba(180, 35, 24, 0.04)`.
  static const Color errorFill = Color(0x0AB42318);

  /// The focus and error rings' `0 0 0 2px`.
  static const double ringWidth = 2;

  /// `.fm-pff__req` `top: -7px; inset-inline-end: -5px`, top.
  static const double asteriskTop = 7;

  /// `.fm-pff__req` `inset-inline-end: -5px`.
  static const double asteriskEnd = 5;

  /// `.fm-pff__req` `font: 600 12px/1`.
  static const double asteriskFontSize = 12;

  /// `.fm-pff__msg` and `.fm-pff__label` sizes: `11px/14px` and `10px/12px`.
  static const double messageFontSize = 11;

  /// `.fm-pff__msg` line height.
  static const double messageLineHeight = 14;

  /// `.fm-pff__label` `font: 500 10px/12px`.
  static const double labelFontSize = 10;

  /// `.fm-pff__label` line height.
  static const double labelLineHeight = 12;

  /// `.fm-pff__msg` glyph `size: 12`; also the date and dropdown glyphs.
  static const double smallIconSize = 12;

  /// `.fm-pff__box--check`, `--radio` `width` and `height: 16px`.
  static const double checkSize = 16;

  /// The check's `strokeWidth: 2.5`.
  static const double checkStroke = 2.5;

  /// `.fm-pff__dot` `width` and `height: 8px`.
  static const double dotSize = 8;

  /// `.fm-pff__box--signature` `height: 44px`.
  static const double signatureHeight = 44;

  /// `.fm-pff__box--signature` `padding: 0 10px`.
  static const double signaturePaddingX = 10;

  /// `.fm-pff__box--signature` `border-width: 1.5px` (dashed).
  static const double signatureBorder = 1.5;

  /// `.is-signed` `font: italic 400 22px/1 var(--font-brand)`.
  static const double signedFontSize = 22;

  /// The 1.5 px dashes of the signature box as Chromium draws them.
  static const double dashLength = 3;

  /// The gaps between those dashes.
  static const double dashGap = 2;

  /// `.fm-pff__box--multiline` `min-height: 54px`.
  static const double multilineMinHeight = 54;

  /// `.fm-pff__box--multiline` `line-height: 16px`.
  static const double multilineLineHeight = 16;

  /// The kind of field.
  final PdfFormFieldType type;

  /// The forced look; null derives it from [error], the value and focus.
  final PdfFormFieldState? state;

  /// The text, date or chosen option.
  final String? value;

  /// The text shown while there is no value (the dropdown's "Choose").
  final String? placeholder;

  /// The label above the field; null shows none.
  final String? label;

  /// Whether the field must be filled (a red asterisk, `aria-required`).
  final bool required;

  /// The error under the field; null for none.
  final String? error;

  /// The dropdown's choices.
  final List<String> options;

  /// The field's width (not checkboxes and radios).
  final double width;

  /// Whether a checkbox or radio is checked.
  final bool? checked;

  /// The signer's name once signed; null shows "Sign here".
  final String? signedAs;

  /// Called with the text after each edit, or the dropdown's choice; null
  /// makes the field read-only.
  final ValueChanged<String>? onChanged;

  /// Called when a checkbox, radio or signature is activated.
  final VoidCallback? onPressed;

  /// The signature box's call to action, the localized "Sign here". Not a
  /// design-system prop.
  final String? signHereLabel;

  /// The accessible name; null takes [label] (and for a signature, "Sign
  /// here" or [signedAs]). Not a design-system prop.
  final String? semanticLabel;

  /// The field's focus node; one is created when null.
  final FocusNode? focusNode;

  /// Whether the field takes focus when it first appears.
  final bool autofocus;

  /// The look before focus and the pointer: [state], else derived as the
  /// bundle derives it.
  PdfFormFieldState get derivedState =>
      state ??
      (error != null
          ? PdfFormFieldState.error
          : ((value?.isNotEmpty ?? false) ||
                    (checked ?? false) ||
                    signedAs != null
                ? PdfFormFieldState.filled
                : PdfFormFieldState.empty));

  @override
  State<PdfFormField> createState() => _PdfFormFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<PdfFormFieldType>(
          'type',
          type,
          defaultValue: PdfFormFieldType.text,
        ),
      )
      ..add(EnumProperty<PdfFormFieldState>('state', state, defaultValue: null))
      ..add(StringProperty('value', value, defaultValue: null))
      ..add(StringProperty('placeholder', placeholder, defaultValue: null))
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(FlagProperty('required', value: required, ifTrue: 'required'))
      ..add(StringProperty('error', error, defaultValue: null))
      ..add(IterableProperty<String>('options', options, ifEmpty: 'none'))
      ..add(DoubleProperty('width', width, defaultValue: 160))
      ..add(
        FlagProperty(
          'checked',
          value: checked,
          ifTrue: 'checked',
          ifFalse: 'unchecked',
        ),
      )
      ..add(StringProperty('signedAs', signedAs, defaultValue: null));
  }
}

class _OpenIntent extends Intent {
  const new();
}

class _PdfFormFieldState extends State<PdfFormField> {
  FocusNode? _ownNode;
  TextEditingController? _controller;
  bool _focused = false;
  bool _hovered = false;
  bool _open = false;

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'PdfFormField'));

  TextEditingController get _text =>
      _controller ??= TextEditingController(text: widget.value ?? '')
        ..addListener(_onText);

  bool get _editable =>
      widget.onChanged != null &&
      widget.derivedState != PdfFormFieldState.readonly;

  bool _empty = true;

  void _onText() {
    final empty = _controller?.text.isEmpty ?? true;
    if (empty != _empty) setState(() => _empty = empty);
  }

  @override
  void didUpdateWidget(PdfFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    final value = widget.value ?? '';
    if (controller != null && controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  /// The look after focus and the pointer.
  PdfFormFieldState _look(Set<WidgetState> forced) {
    final base = widget.derivedState;
    if (base == PdfFormFieldState.readonly || base == PdfFormFieldState.error) {
      return base;
    }
    if (_focused || forced.contains(WidgetState.focused)) {
      return PdfFormFieldState.focus;
    }
    return base;
  }

  BoxDecoration _decoration(
    FermanTheme theme,
    PdfFormFieldState look, {
    required bool hovered,
    BoxShape shape = BoxShape.rectangle,
  }) {
    final page = theme.pageColors;
    final ramps = theme.ramps;
    final width = theme.border.borderWidth;
    final radius = shape == BoxShape.circle
        ? null
        : const BorderRadius.all(Radius.circular(PdfFormField.boxRadius));
    return switch (look) {
      PdfFormFieldState.empty => BoxDecoration(
        color: page.formFieldBg,
        shape: shape,
        borderRadius: radius,
        border: Border.all(
          color: hovered ? ramps.ink400 : page.formFieldBorder,
          width: width,
        ),
      ),
      PdfFormFieldState.filled => BoxDecoration(
        color: PdfFormField.filledFill,
        shape: shape,
        borderRadius: radius,
        border: Border.all(color: PdfFormField.filledBorder, width: width),
      ),
      PdfFormFieldState.focus => BoxDecoration(
        color: PdfFormField.focusFill,
        shape: shape,
        borderRadius: radius,
        border: Border.all(color: page.formFieldFocus, width: width),
        boxShadow: const [
          BoxShadow(
            color: PdfFormField.focusRing,
            spreadRadius: PdfFormField.ringWidth,
          ),
        ],
      ),
      PdfFormFieldState.error => BoxDecoration(
        color: PdfFormField.errorFill,
        shape: shape,
        borderRadius: radius,
        border: Border.all(color: ramps.red600, width: width),
        boxShadow: const [
          BoxShadow(
            color: PdfFormField.errorRing,
            spreadRadius: PdfFormField.ringWidth,
          ),
        ],
      ),
      PdfFormFieldState.readonly => BoxDecoration(
        shape: shape,
        border: Border(
          bottom: BorderSide(color: ramps.paper400, width: width),
        ),
      ),
    };
  }

  TextStyle _valueStyle(FermanTheme theme) => theme.typography.body.copyWith(
    fontFamily: theme.typeScale.fontDocSample.family,
    fontSize: PdfFormField.valueFontSize,
    height: 1,
    fontWeight: theme.typeScale.weightRegular,
    color: theme.ramps.paper900,
  );

  TextStyle _placeholderStyle(FermanTheme theme) =>
      theme.typography.body.copyWith(
        fontSize: PdfFormField.placeholderFontSize,
        height: 1,
        color: theme.ramps.paper500,
      );

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final forced = FermanForcedStates.of(context);
    final look = _look(forced);
    final hovered = _hovered || forced.contains(WidgetState.hovered);
    final hoverEmpty = hovered && look == PdfFormFieldState.empty;
    return switch (widget.type) {
      PdfFormFieldType.checkbox ||
      PdfFormFieldType.radio => _choice(theme, look, hoverEmpty),
      PdfFormFieldType.signature => _signature(theme, look, hoverEmpty),
      PdfFormFieldType.dropdown => _dropdown(theme, look, hoverEmpty),
      PdfFormFieldType.text ||
      PdfFormFieldType.date ||
      PdfFormFieldType.multiline => _textField(theme, look, hoverEmpty),
    };
  }

  /// The label, the box with its asterisk, and the message.
  Widget _frame(
    FermanTheme theme,
    Widget box, {
    bool sized = true,
    bool messageIcon = true,
  }) {
    final label = widget.label;
    final error = widget.error;
    final showError =
        error != null && widget.derivedState == PdfFormFieldState.error;
    final ramps = theme.ramps;
    final message = TextStyle(
      fontSize: PdfFormField.messageFontSize,
      height: PdfFormField.messageLineHeight / PdfFormField.messageFontSize,
      fontWeight: theme.typeScale.weightRegular,
      color: ramps.red600,
    );
    var boxed = box;
    if (widget.required) {
      boxed = Stack(
        clipBehavior: Clip.none,
        children: [
          box,
          PositionedDirectional(
            top: -PdfFormField.asteriskTop,
            end: -PdfFormField.asteriskEnd,
            child: ExcludeSemantics(
              child: Text(
                '*',
                key: const ValueKey<String>('PdfFormField.required'),
                style: theme.typography.body.copyWith(
                  fontSize: PdfFormField.asteriskFontSize,
                  height: 1,
                  fontWeight: theme.typeScale.weightSemibold,
                  color: theme.pageColors.formFieldRequired,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PdfFormField.gap,
      children: [
        if (label != null && sized)
          ExcludeSemantics(
            child: Text(
              label,
              style: theme.typography.body.copyWith(
                fontSize: PdfFormField.labelFontSize,
                height:
                    PdfFormField.labelLineHeight / PdfFormField.labelFontSize,
                fontWeight: theme.typeScale.weightMedium,
                color: ramps.paper600,
              ),
            ),
          ),
        boxed,
        if (showError)
          ExcludeSemantics(
            child: Row(
              key: const ValueKey<String>('PdfFormField.error'),
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.space1,
              children: [
                if (messageIcon)
                  Icon(
                    IconName.circleAlert,
                    size: PdfFormField.smallIconSize,
                    color: ramps.red600,
                  ),
                Flexible(
                  child: Text(
                    error,
                    style: theme.typography.body.merge(message),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return sized ? SizedBox(width: widget.width, child: column) : column;
  }

  /// Focus, hover and keyboard around a box that is not a text input.
  Widget _detector({
    required Widget child,
    required Map<ShortcutActivator, Intent> shortcuts,
    required VoidCallback? onActivate,
    required bool enabled,
  }) => FocusableActionDetector(
    focusNode: _node,
    autofocus: widget.autofocus,
    enabled: enabled,
    includeFocusSemantics: false,
    shortcuts: shortcuts,
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          onActivate?.call();
          return null;
        },
      ),
      _OpenIntent: CallbackAction<_OpenIntent>(
        onInvoke: (_) {
          onActivate?.call();
          return null;
        },
      ),
    },
    onFocusChange: (value) => setState(() => _focused = value),
    onShowHoverHighlight: (value) => setState(() => _hovered = value),
    mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: enabled
          ? () {
              _node.requestFocus();
              onActivate?.call();
            }
          : null,
      child: child,
    ),
  );

  Widget _choice(FermanTheme theme, PdfFormFieldState look, bool hovered) {
    final radio = widget.type == PdfFormFieldType.radio;
    final checked = widget.checked ?? false;
    final enabled =
        widget.onPressed != null && look != PdfFormFieldState.readonly;
    final ink = theme.ramps.paper900;
    final box = Container(
      key: const ValueKey<String>('PdfFormField.box'),
      width: PdfFormField.checkSize,
      height: PdfFormField.checkSize,
      alignment: Alignment.center,
      decoration: _decoration(
        theme,
        look,
        hovered: hovered,
        shape: radio && look != PdfFormFieldState.readonly
            ? BoxShape.circle
            : BoxShape.rectangle,
      ),
      child: !checked
          ? null
          : radio
          ? Container(
              width: PdfFormField.dotSize,
              height: PdfFormField.dotSize,
              decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
            )
          : Icon(
              IconName.check,
              size: PdfFormField.smallIconSize,
              strokeWidth: PdfFormField.checkStroke,
              color: ink,
            ),
    );
    return _semantics(
      checked: checked,
      radio: radio,
      enabled: enabled,
      onTap: enabled ? widget.onPressed : null,
      child: _frame(
        theme,
        _detector(
          enabled: enabled,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          onActivate: widget.onPressed,
          child: box,
        ),
        sized: false,
        messageIcon: false,
      ),
    );
  }

  Widget _signature(FermanTheme theme, PdfFormFieldState look, bool hovered) {
    final signedAs = widget.signedAs;
    final enabled =
        widget.onPressed != null && look != PdfFormFieldState.readonly;
    final ramps = theme.ramps;
    final decoration = _decoration(theme, look, hovered: hovered);
    final readonly = look == PdfFormFieldState.readonly;
    final borderColor = readonly
        ? ramps.paper400
        : (decoration.border! as Border).top.color;
    final Widget content;
    if (signedAs != null) {
      content = Text(
        signedAs,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: theme.typography.body.copyWith(
          fontFamily: theme.typeScale.fontBrand.family,
          fontStyle: FontStyle.italic,
          fontSize: PdfFormField.signedFontSize,
          height: 1,
          fontWeight: theme.typeScale.weightRegular,
          color: ramps.ink800,
        ),
      );
    } else {
      final call = widget.signHereLabel;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space1_5,
        children: [
          // `size: 16`, the Icon default.
          Icon(IconName.signature, color: ramps.ink600),
          if (call != null)
            Flexible(
              child: Text(
                call,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(
                  fontSize: PdfFormField.valueFontSize,
                  color: ramps.ink600,
                ),
              ),
            ),
        ],
      );
    }
    final box = Container(
      key: const ValueKey<String>('PdfFormField.box'),
      height: PdfFormField.signatureHeight,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PdfFormField.signaturePaddingX,
      ),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: decoration.color,
        boxShadow: decoration.boxShadow,
        borderRadius: readonly ? null : decoration.borderRadius,
        border: signedAs != null || readonly ? decoration.border : null,
      ),
      // The field's semantics name it; the drawn text is not read twice.
      child: ExcludeSemantics(child: content),
    );
    final framed = signedAs != null || readonly
        ? box
        : CustomPaint(
            foregroundPainter: _DashedBoxPainter(color: borderColor),
            child: box,
          );
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        isRequired: widget.required ? true : null,
        label:
            widget.semanticLabel ??
            signedAs ??
            widget.signHereLabel ??
            widget.label,
        hint: widget.error,
        validationResult: widget.error == null
            ? SemanticsValidationResult.none
            : SemanticsValidationResult.invalid,
        onTap: enabled ? widget.onPressed : null,
        child: _frame(
          theme,
          _detector(
            enabled: enabled,
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            onActivate: widget.onPressed,
            child: framed,
          ),
        ),
      ),
    );
  }

  Widget _dropdown(FermanTheme theme, PdfFormFieldState look, bool hovered) {
    final value = widget.value;
    final hasValue = value != null && value.isNotEmpty;
    final enabled =
        widget.onChanged != null &&
        look != PdfFormFieldState.readonly &&
        widget.options.isNotEmpty;
    final decoration = _decoration(theme, look, hovered: hovered);
    final box = Container(
      key: const ValueKey<String>('PdfFormField.box'),
      height: PdfFormField.boxHeight,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PdfFormField.boxPaddingX,
      ),
      decoration: decoration,
      child: Row(
        spacing: theme.space.space1,
        children: [
          Expanded(
            child: Text(
              semanticsLabel: '',
              hasValue ? value : (widget.placeholder ?? ''),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: _valueStyle(theme),
            ),
          ),
          Icon(
            IconName.chevronDown,
            size: PdfFormField.smallIconSize,
            color: theme.ramps.paper600,
          ),
        ],
      ),
    );
    void open() => setState(() => _open = true);
    void close() {
      setState(() => _open = false);
      _node.requestFocus();
    }

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        expanded: _open,
        isRequired: widget.required ? true : null,
        label: widget.semanticLabel ?? widget.label,
        value: hasValue ? value : null,
        hint: widget.error ?? (hasValue ? null : widget.placeholder),
        validationResult: widget.error == null
            ? SemanticsValidationResult.none
            : SemanticsValidationResult.invalid,
        onTap: enabled ? open : null,
        child: _frame(
          theme,
          Popover(
            open: _open && enabled,
            surface: false,
            onDismiss: close,
            anchor: _detector(
              enabled: enabled,
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown): _OpenIntent(),
              },
              onActivate: open,
              child: box,
            ),
            child: Menu(
              autofocus: true,
              semanticLabel: widget.label,
              items: [
                for (final option in widget.options)
                  MenuItem(label: option, checked: option == value),
              ],
              onSelected: (item) {
                close();
                widget.onChanged?.call(item.label);
              },
              onClose: close,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(FermanTheme theme, PdfFormFieldState look, bool hovered) {
    final multiline = widget.type == PdfFormFieldType.multiline;
    final decoration = _decoration(theme, look, hovered: hovered);
    final valueStyle = _valueStyle(theme);
    final placeholder = widget.placeholder;
    final Widget input;
    if (_editable) {
      _empty = _text.text.isEmpty;
      final style = multiline
          ? valueStyle.copyWith(
              height:
                  PdfFormField.multilineLineHeight / PdfFormField.valueFontSize,
            )
          : valueStyle;
      final editor = multiline
          ? _MultilineInput(
              controller: _text,
              focusNode: _node,
              style: style,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
            )
          : FieldInput(
              controller: _text,
              focusNode: _node,
              style: style,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
            );
      input = Stack(
        alignment: multiline
            ? AlignmentDirectional.topStart
            : AlignmentDirectional.centerStart,
        children: [
          if (placeholder != null && _empty)
            ExcludeSemantics(
              child: Text(
                placeholder,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: _placeholderStyle(theme),
              ),
            ),
          editor,
        ],
      );
    } else {
      final value = widget.value ?? '';
      input = Text(
        semanticsLabel: '',
        value.isEmpty ? (placeholder ?? '') : value,
        maxLines: multiline ? null : 1,
        softWrap: multiline,
        overflow: multiline ? null : TextOverflow.clip,
        style: value.isEmpty ? _placeholderStyle(theme) : valueStyle,
      );
    }
    final glyph = switch (widget.type) {
      PdfFormFieldType.date => IconName.calendar,
      _ => null,
    };
    Widget box = Container(
      key: const ValueKey<String>('PdfFormField.box'),
      height: multiline ? null : PdfFormField.boxHeight,
      constraints: multiline
          ? const BoxConstraints(minHeight: PdfFormField.multilineMinHeight)
          : null,
      padding: multiline
          ? const EdgeInsetsDirectional.all(PdfFormField.boxPaddingX)
          : const EdgeInsetsDirectional.symmetric(
              horizontal: PdfFormField.boxPaddingX,
            ),
      decoration: decoration,
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        spacing: theme.space.space1,
        children: [
          Expanded(child: input),
          if (glyph != null)
            Icon(
              glyph,
              size: PdfFormField.smallIconSize,
              color: theme.ramps.paper600,
            ),
        ],
      ),
    );
    // `:focus-within` and `:hover` on the box.
    box = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        opaque: false,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: box,
      ),
    );
    return MergeSemantics(
      child: Semantics(
        textField: !_editable ? true : null,
        readOnly: !_editable,
        multiline: multiline ? true : null,
        isRequired: widget.required ? true : null,
        label: widget.semanticLabel ?? widget.label,
        value: !_editable ? widget.value : null,
        hint: widget.error ?? placeholder,
        validationResult: widget.error == null
            ? SemanticsValidationResult.none
            : SemanticsValidationResult.invalid,
        child: _frame(theme, box),
      ),
    );
  }

  Widget _semantics({
    required bool checked,
    required bool radio,
    required bool enabled,
    required VoidCallback? onTap,
    required Widget child,
  }) => MergeSemantics(
    child: Semantics(
      checked: checked,
      inMutuallyExclusiveGroup: radio ? true : null,
      enabled: enabled,
      focusable: enabled,
      isRequired: widget.required ? true : null,
      label: widget.semanticLabel ?? widget.label,
      hint: widget.error,
      validationResult: widget.error == null
          ? SemanticsValidationResult.none
          : SemanticsValidationResult.invalid,
      onTap: onTap,
      child: child,
    ),
  );
}

/// A multiline text control for the multiline field: [EditableText] with
/// click and drag selection (`textarea`, three rows).
class _MultilineInput extends StatefulWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.autofocus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<_MultilineInput> createState() => _MultilineInputState();
}

class _MultilineInputState extends State<_MultilineInput>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: _gestures.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: EditableText(
          key: editableTextKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          style: widget.style,
          cursorColor: widget.style.color ?? theme.ramps.paper900,
          backgroundCursorColor: theme.ramps.paper400,
          cursorWidth: FieldInput.caretWidth,
          selectionColor: theme.pageColors.editSelection,
          autofocus: widget.autofocus,
          maxLines: null,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          onChanged: widget.onChanged,
          rendererIgnoresPointer: true,
          selectionControls: emptyTextSelectionControls,
        ),
      ),
    );
  }
}

/// Paints the signature box's dashed border: [PdfFormField.signatureBorder]
/// wide, inside the box, with 2 px corners.
class _DashedBoxPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const width = PdfFormField.signatureBorder;
    final box = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      const Radius.circular(PdfFormField.boxRadius - width / 2),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    for (final metric in (Path()..addRRect(box)).computeMetrics()) {
      for (
        var at = 0.0;
        at < metric.length;
        at += PdfFormField.dashLength + PdfFormField.dashGap
      ) {
        canvas.drawPath(
          metric.extractPath(
            at,
            math.min(at + PdfFormField.dashLength, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter oldDelegate) =>
      oldDelegate.color != color;
}
