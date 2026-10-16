import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The single-line text control inside a field box (`.fm-input__control`,
/// `.fm-palette__field`), built on [EditableText], never on the Material
/// text field (ADR 0011).
///
/// It adds to [EditableText] what the browser's `<input>` gives the
/// design: the [placeholder] in tertiary text while the field is empty
/// (`::placeholder`), click and drag selection
/// ([TextSelectionGestureDetectorBuilder]), the text cursor, and the
/// design's selection colour (`::selection`, `--edit-selection`). The caret
/// is 1 px of the text colour; it blinks as [EditableText]'s caret does.
///
/// [enabled] false makes it inert: not focusable, not editable, no pointer
/// input, under the not-allowed cursor (`.fm-input__control:disabled`).
/// [readOnly] keeps it focusable and selectable without editing, for a
/// control that is disabled with a reason (G10). [obscureText] masks the
/// text (the bundle's `type="password"`).
///
/// The whole control, not only its text line, is inside the text field's
/// tap region, so a click anywhere in it never counts as outside the
/// field. A right click opens no context menu yet (keyboard copy and
/// paste work; G80, B017).
///
/// It announces itself as a text field with its value; the owning
/// component adds the label and hint around it.
class FieldInput extends StatefulWidget {
  /// Creates the control.
  const new({
    required this.controller,
    required this.focusNode,
    required this.style,
    super.key,
    this.placeholder,
    this.placeholderColor,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.mouseCursor,
    this.obscureText = false,
  });

  /// The text being edited.
  final TextEditingController controller;

  /// The control's focus node.
  final FocusNode focusNode;

  /// The text style (`font: var(--type-body)` and the like).
  final TextStyle style;

  /// The text shown while the field is empty; null shows none.
  final String? placeholder;

  /// The placeholder colour; null takes the tertiary text colour.
  final Color? placeholderColor;

  /// Whether the control takes focus and input.
  final bool enabled;

  /// Whether the text can be focused and selected but not changed.
  final bool readOnly;

  /// Whether the control takes focus when it first appears.
  final bool autofocus;

  /// How the text lines up in the control.
  final TextAlign textAlign;

  /// The kind of on-screen keyboard to show; null for plain text.
  final TextInputType? keyboardType;

  /// Formatters applied to every edit.
  final List<TextInputFormatter>? inputFormatters;

  /// Called with the text after each edit.
  final ValueChanged<String>? onChanged;

  /// Called with the text when the user submits it (Enter).
  final ValueChanged<String>? onSubmitted;

  /// Called when the user submits; replaces the default of giving up
  /// focus.
  final VoidCallback? onEditingComplete;

  /// The pointer cursor over the control; null shows the text cursor
  /// while editable.
  final MouseCursor? mouseCursor;

  /// Whether the text is masked (a password or PIN): no suggestions,
  /// autocorrect, copy or cut, and screen readers hear it as obscured.
  final bool obscureText;

  /// The caret width (a 1 px browser caret).
  static const double caretWidth = 1;

  @override
  State<FieldInput> createState() => _FieldInputState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('placeholder', placeholder, defaultValue: null))
      ..add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'))
      ..add(FlagProperty('readOnly', value: readOnly, ifTrue: 'read only'))
      ..add(
        FlagProperty('obscureText', value: obscureText, ifTrue: 'obscured'),
      );
  }
}

class _FieldInputState extends State<FieldInput>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(FieldInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  bool _empty = true;

  void _onText() {
    final empty = widget.controller.text.isEmpty;
    if (empty != _empty) setState(() => _empty = empty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    _empty = widget.controller.text.isEmpty;
    final editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: widget.style,
      cursorColor: widget.style.color ?? theme.colors.textPrimary,
      backgroundCursorColor: theme.colors.textTertiary,
      cursorWidth: FieldInput.caretWidth,
      selectionColor: theme.pageColors.editSelection,
      readOnly: widget.readOnly || !widget.enabled,
      obscureText: widget.obscureText,
      autocorrect: !widget.obscureText,
      enableSuggestions: !widget.obscureText,
      showCursor: !widget.readOnly && widget.enabled,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      rendererIgnoresPointer: true,
      enableInteractiveSelection: widget.enabled,
      selectionControls: emptyTextSelectionControls,
      mouseCursor: widget.mouseCursor,
    );
    final placeholder = widget.placeholder;
    var result = _gestures.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (placeholder != null && _empty)
            ExcludeSemantics(
              child: Text(
                placeholder,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textAlign: widget.textAlign,
                style: widget.style.copyWith(
                  color: widget.placeholderColor ?? theme.colors.textTertiary,
                ),
              ),
            ),
          editable,
        ],
      ),
    );
    // A pointer down anywhere in the control is inside the field, as
    // Flutter's own text fields count it.
    result = TextFieldTapRegion(child: result);
    if (!widget.enabled) {
      result = ExcludeFocus(child: IgnorePointer(child: result));
    }
    // Outermost, so the not-allowed cursor of an inert control shows: an
    // opaque MouseRegion takes the hover even when its child does not.
    return MouseRegion(
      cursor:
          widget.mouseCursor ??
          (widget.enabled && !widget.readOnly
              ? SystemMouseCursors.text
              : SystemMouseCursors.forbidden),
      child: result,
    );
  }
}
