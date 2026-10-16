import 'dart:ui' show SemanticsValidationResult;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A single-line text input with a label, a hint or error, a leading icon
/// and a unit suffix, the design-system `TextField` component
/// (`components/forms/TextField.jsx`, `.fm-field`, `.fm-input`). Never the
/// Material text field (ADR 0011): files that also import Material hide
/// its `TextField`.
///
/// The box is a [Field] of [size]: [icon] leads at 14 px (small) or 16 px
/// (medium) in the secondary icon colour, the text control ([FieldInput]
/// on [EditableText]) takes the rest, and [suffix] (a unit such as "pt")
/// trails in tertiary caption text (`.fm-input__suffix`). [placeholder]
/// shows while the text is empty. [error] replaces [hint] under the box
/// and turns its border the danger colour.
///
/// The text lives in [controller] (one is created when null) and changes
/// are reported through [onChanged]; Enter calls [onSubmitted] and the
/// field keeps focus, as a native input does. [obscureText] masks the text
/// (the boards' `type="password"`). The whole box height takes clicks, and
/// a click on [label] focuses the field.
///
/// **Disabled.** [disabled] gives the sunken, subtle-bordered look with
/// disabled text, and the field takes no focus or input. With
/// [disabledReason] (G10) it stays focusable and selectable, so keyboard
/// and screen-reader users can read why: the reason shows as its tooltip
/// and is announced as its hint, and the text cannot be changed.
///
/// For screen readers the field is a text field named by [label] (or
/// [semanticLabel] when no label is shown), with [error], or else [hint]
/// or [placeholder], as its hint, and marked invalid while [error] is set
/// (`aria-invalid`).
class TextField extends StatefulWidget {
  /// Creates a text field.
  const new({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.icon,
    this.suffix,
    this.size = FieldSize.md,
    this.disabled = false,
    this.disabledReason,
    this.focusNode,
    this.controller,
    this.placeholder,
    this.semanticLabel,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
  });

  /// The label above the box; null shows none.
  final String? label;

  /// The hint under the box; null shows none.
  final String? hint;

  /// The error under the box, replacing [hint]; null for none. Validators
  /// return a `bool` and check null and empty values explicitly (brief
  /// §6); the screen turns a failed check into this message.
  final String? error;

  /// The leading icon; null shows none.
  final IconName? icon;

  /// The unit after the text, such as "pt"; null shows none.
  final String? suffix;

  /// The height, padding and text size.
  final FieldSize size;

  /// Whether the field is disabled.
  final bool disabled;

  /// Why the field is disabled: its tooltip and semantics hint while
  /// [disabled] (G10).
  final String? disabledReason;

  /// The focus node of the text control (the bundle's `inputRef`); one is
  /// created when null.
  final FocusNode? focusNode;

  /// The text being edited; one is created when null.
  final TextEditingController? controller;

  /// The text shown while the field is empty; null shows none.
  final String? placeholder;

  /// The accessible name when no [label] is shown (`aria-label`).
  final String? semanticLabel;

  /// Called with the text after each edit.
  final ValueChanged<String>? onChanged;

  /// Called with the text when Enter submits it.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field takes focus when it first appears.
  final bool autofocus;

  /// Formatters applied to every edit. Not a design-system prop.
  final List<TextInputFormatter>? inputFormatters;

  /// The on-screen keyboard; null for plain text. Not a design-system
  /// prop.
  final TextInputType? keyboardType;

  /// Whether the text is masked: the bundle's `type="password"`, passed
  /// through `...rest` (a1-8, a5-6b, a8-1, a10-2). Not a design-system
  /// prop.
  final bool obscureText;

  @override
  State<TextField> createState() => _TextFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(StringProperty('hint', hint, defaultValue: null))
      ..add(StringProperty('error', error, defaultValue: null))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(StringProperty('suffix', suffix, defaultValue: null))
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.md))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      )
      ..add(StringProperty('placeholder', placeholder, defaultValue: null))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null))
      ..add(
        FlagProperty('obscureText', value: obscureText, ifTrue: 'obscured'),
      );
  }
}

class _TextFieldState extends State<TextField> {
  TextEditingController? _ownController;
  FocusNode? _ownNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'TextField'));

  bool get _showsReason => widget.disabled && widget.disabledReason != null;

  @override
  void dispose() {
    _ownController?.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final disabled = widget.disabled;
    final reason = _showsReason ? widget.disabledReason : null;
    final icon = widget.icon;
    final suffix = widget.suffix;
    final textColor = disabled ? colors.textDisabled : colors.textPrimary;
    final input = FieldInput(
      controller: _controller,
      focusNode: _node,
      style: FieldBox.textStyleOf(theme, widget.size, color: textColor),
      placeholder: widget.placeholder,
      enabled: !disabled || reason != null,
      readOnly: disabled,
      autofocus: widget.autofocus,
      inputFormatters: widget.inputFormatters,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      // Keeps focus on Enter (the default gives it up), clearing the
      // composing region as the default does.
      onEditingComplete: _controller.clearComposing,
      obscureText: widget.obscureText,
    );
    final box = Row(
      spacing: FieldBox.contentGap,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: FieldBox.iconSizeOf(theme, widget.size),
            color: colors.iconSecondary,
          ),
        // `.fm-input__control { height: 100% }`: the control takes the
        // box's full height, so a click above or below the text line
        // lands in it.
        Expanded(
          child: SizedBox(height: double.infinity, child: input),
        ),
        if (suffix != null)
          ExcludeSemantics(
            child: Text(
              suffix,
              style: theme.typography.caption.copyWith(
                color: colors.textTertiary,
                fontFeatures: theme.typeScale.numericTabular,
              ),
            ),
          ),
      ],
    );
    final hints = [
      ?reason,
      widget.error ?? widget.hint ?? widget.placeholder,
    ].whereType<String>();
    Widget result = MergeSemantics(
      child: Semantics(
        label: widget.label ?? widget.semanticLabel,
        hint: hints.isEmpty ? null : hints.join('\n'),
        enabled: !disabled,
        // The bundle's `aria-invalid`.
        validationResult: widget.error == null
            ? SemanticsValidationResult.none
            : SemanticsValidationResult.invalid,
        child: Field(
          label: widget.label,
          hint: widget.hint,
          error: widget.error,
          size: widget.size,
          disabled: disabled,
          // A plain disabled field stays inert, as a disabled input does.
          onLabelTap: disabled && reason == null ? null : _node.requestFocus,
          child: box,
        ),
      ),
    );
    if (reason != null) {
      result = Tooltip(
        message: reason,
        excludeFromSemantics: true,
        child: result,
      );
    }
    return result;
  }
}
