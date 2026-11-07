import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The message a field shows under it (a5-2, a5-2b): what its value fails,
/// or, once Finish was asked for, that it is required; null for none.
String? fieldError(
  AppLocalizations l10n,
  FieldInfo field,
  RegionFormat format, {
  required bool attempted,
}) {
  String number(double value) => format.decimal(value);
  final problem = field.problem;
  if (problem != null) {
    return switch (problem.kind) {
      FieldProblemKind.tooLong => l10n.formErrorTooLong(
        problem.maxLen ?? 0,
        format.integer(problem.maxLen ?? 0),
      ),
      FieldProblemKind.notADate => l10n.formErrorDate(problem.pattern ?? ''),
      FieldProblemKind.notANumber => l10n.formErrorNumber,
      FieldProblemKind.outOfRange => switch ((problem.min, problem.max)) {
        (final min?, final max?) => l10n.formErrorRange(
          number(min),
          number(max),
        ),
        (final min?, null) => l10n.formErrorMin(number(min)),
        (null, final max?) => l10n.formErrorMax(number(max)),
        (null, null) => l10n.formErrorNumber,
      },
    };
  }
  if (!attempted || !field.required || field.filled) return null;
  return switch (field.kind) {
    FieldKind.signature => l10n.formErrorSign,
    FieldKind.combo || FieldKind.list => l10n.formErrorChoose,
    _ => l10n.formErrorRequired,
  };
}

/// [date] in an `AFDate` pattern such as `dd.mm.yyyy` or `m/d/yy`.
String formatFieldDate(String pattern, DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return pattern.replaceAllMapped(RegExp('yyyy|yy|mm|m|dd|d'), (match) {
    return switch (match[0]) {
      'yyyy' => date.year.toString().padLeft(4, '0'),
      'yy' => two(date.year % 100),
      'mm' => two(date.month),
      'm' => '${date.month}',
      'dd' => two(date.day),
      _ => '${date.day}',
    };
  });
}

/// Fill & Sign's layer over the pages (a5-1, a5-2, a5-2b): every form field's
/// box in its look, its value (the canvas draws no widget, B203), the
/// required asterisk, the tab order, and the field the person is in with its
/// editor, which commits on blur, Tab or Enter (M4 decision 16).
///
/// It sits in the canvas's left-to-right geometry, which never mirrors; its
/// menus and messages follow [uiDirection].
class FormOverlay extends ConsumerWidget {
  /// The layer over [view].
  const new({required this.view, required this.uiDirection, super.key});

  /// The canvas as it stands.
  final ViewerState view;

  /// The UI's direction.
  final TextDirection uiDirection;

  /// The tab-order badge (DocForm: `min-width: 16px; height: 16px`).
  static const double orderSize = 16;

  /// Its place: `top: -4px; left: -22px`.
  static const double orderTop = 4;

  /// See [orderTop].
  static const double orderStart = 22;

  /// The largest value text, in points (`PdfFormField.valueFontSize`).
  static const double largestText = 12;

  /// The value text's share of a box's height.
  static const double textShare = 0.7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(documentFormProvider).value;
    if (form == null || form.fields.isEmpty) return const SizedBox.shrink();
    final session = ref.watch(formSessionProvider);
    final refused = ref.watch(fillRefusalProvider) != null;
    final fillable = fillableFields(form);
    final boxes = <Widget>[];
    for (final field in form.fields) {
      if (field.kind == FieldKind.push) continue;
      final order = fillable.indexOf(field);
      for (final (place, widget) in field.widgets.indexed) {
        final page = view.document.pageIndexOf(widget.page);
        final pageRect = page == null
            ? null
            : view.placement.rects.elementAtOrNull(page);
        if (pageRect == null || !pageRect.overlaps(view.visible)) continue;
        final box = Rect.fromLTRB(
          pageRect.left + widget.rect.left * view.scale,
          pageRect.top + widget.rect.top * view.scale,
          pageRect.left + widget.rect.right * view.scale,
          pageRect.top + widget.rect.bottom * view.scale,
        ).shift(-view.offset);
        boxes.add(
          PositionedDirectional(
            key: ValueKey(('field', field.handle, place)),
            start: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
            child: _FieldBox(
              field: field,
              widget: widget,
              scale: view.scale,
              order: session.order && place == 0 && order >= 0
                  ? order + 1
                  : null,
              current: session.current == field.handle,
              first: place == 0,
              last: order == fillable.length - 1,
              highlight: session.highlight,
              attempted: session.attempted,
              marked: session.marked.contains(field.handle),
              editable: !refused && !field.readOnly,
              uiDirection: uiDirection,
              form: form,
              document: view.document.id,
            ),
          ),
        );
      }
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // A click off the fields leaves them and gives the canvas its keys.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              Focus.maybeOf(context)?.requestFocus();
              ref.read(formSessionProvider.notifier).focus(null);
            },
          ),
        ),
        ...boxes,
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ViewerState>('view', view))
      ..add(EnumProperty<TextDirection>('uiDirection', uiDirection));
  }
}

/// One place of a field on the page.
class _FieldBox extends ConsumerStatefulWidget {
  const new({
    required this.field,
    required this.widget,
    required this.scale,
    required this.order,
    required this.current,
    required this.first,
    required this.last,
    required this.highlight,
    required this.attempted,
    required this.marked,
    required this.editable,
    required this.uiDirection,
    required this.form,
    required this.document,
  });

  final FieldInfo field;
  final FieldWidget widget;
  final double scale;
  final int? order;
  final bool current;
  final bool first;
  final bool last;
  final bool highlight;
  final bool attempted;
  final bool marked;
  final bool editable;
  final TextDirection uiDirection;
  final FormInfo form;

  /// The document the field is in, by id.
  final int document;

  @override
  ConsumerState<_FieldBox> createState() => _FieldBoxState();
}

class _FieldBoxState extends ConsumerState<_FieldBox> {
  bool _hovered = false;
  bool _menu = false;
  bool _picker = false;
  DateTime? _month;
  late final TextEditingController _text = TextEditingController(text: _shown);
  final FocusNode _focus = FocusNode(debugLabel: 'FormField');

  /// What was last committed or read, so blur commits only a change.
  String _committed = '';

  FieldInfo get _field => widget.field;

  bool get _typed => switch (_field.kind) {
    FieldKind.text => true,
    FieldKind.combo => _field.editable,
    _ => false,
  };

  String get _shown => _field.values.join(', ');

  /// What [dispose] needs, when `ref` no longer answers.
  late final FormCommands _keptCommands;

  @override
  void initState() {
    super.initState();
    _keptCommands = ref.read(formCommandsProvider.notifier);
    _committed = _shown;
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_FieldBox old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _shown != _committed) {
      _committed = _shown;
      _text.text = _shown;
    }
    if (widget.current && !old.current) _takeFocus();
  }

  @override
  void dispose() {
    // A field left by its view, as by a page scrolled away, keeps its typing.
    if (_text.text != _committed) _commit();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _takeFocus() {
    if (!widget.first || !widget.editable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.current && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  FormCommands get _commands => _keptCommands;

  FormSession get _session => ref.read(formSessionProvider.notifier);

  void _commit() {
    if (!_typed || !widget.editable) return;
    final text = _text.text;
    if (text == _committed) return;
    _committed = text;
    unawaited(
      _commands.setValue(
        _field,
        text.isEmpty ? const [] : [text],
        on: widget.document,
      ),
    );
  }

  /// Leaves the field [by] fields along the tab order.
  void _move(int by) {
    _commit();
    _session.move(widget.form, by);
  }

  void _pressed() {
    _session.focus(_field.handle);
    if (!widget.editable) return;
    switch (_field.kind) {
      case FieldKind.check:
        final on = widget.widget.onState ?? 'Yes';
        unawaited(
          _commands.setValue(
            _field,
            _field.values.contains(on) ? const [] : [on],
          ),
        );
      case FieldKind.radio:
        final on = widget.widget.onState;
        if (on != null && !_field.values.contains(on)) {
          unawaited(_commands.setValue(_field, [on]));
        }
      case FieldKind.combo || FieldKind.list when !_typed:
        setState(() => _menu = true);
      // A signature field is the signing tools'; here it only takes focus.
      case _:
        _focus.requestFocus();
    }
  }

  bool get _isDate =>
      _field.format == FieldFormatKind.date && _field.datePattern != null;

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.tab:
        _move(shift ? -1 : 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _text.text = _committed;
        _session.focus(null);
        _focus.unfocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space when !_typed:
        _pressed();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter when !_typed || !_field.multiline:
        if (!_typed) {
          _pressed();
        } else {
          _commit();
          if (widget.last) _commands.finish();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final field = _field;
    final ramps = theme.ramps;
    final page = theme.pageColors;
    final error = widget.first
        ? fieldError(l10n, field, format, attempted: widget.attempted)
        : null;
    final hasError =
        field.problem != null ||
        (widget.attempted && field.required && !field.filled);
    final focused = widget.current;
    final width = theme.border.borderWidth;
    final shape = field.kind == FieldKind.radio
        ? BoxShape.circle
        : BoxShape.rectangle;
    final radius = shape == BoxShape.circle
        ? null
        : const BorderRadius.all(Radius.circular(PdfFormField.boxRadius));
    final BoxDecoration decoration;
    if (field.readOnly) {
      decoration = const BoxDecoration();
    } else if (hasError) {
      decoration = BoxDecoration(
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
      );
    } else if (focused) {
      decoration = BoxDecoration(
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
      );
    } else if (widget.marked) {
      decoration = BoxDecoration(
        color: page.glyphMissingBg,
        shape: shape,
        borderRadius: radius,
        border: Border.all(color: page.glyphMissing, width: width),
      );
    } else if (!widget.highlight) {
      decoration = const BoxDecoration();
    } else if (field.filled) {
      decoration = BoxDecoration(
        color: PdfFormField.filledFill,
        shape: shape,
        borderRadius: radius,
        border: Border.all(color: PdfFormField.filledBorder, width: width),
      );
    } else {
      decoration = BoxDecoration(
        color: page.formFieldBg,
        shape: shape,
        borderRadius: radius,
        border: Border.all(
          color: _hovered ? ramps.ink400 : page.formFieldBorder,
          width: width,
        ),
      );
    }
    final box = widget.widget.rect;
    final size = math.min(
      FormOverlay.largestText,
      box.height * FormOverlay.textShare,
    );
    final style = theme.typography.body.copyWith(
      fontFamily: theme.typeScale.fontDocSample.family,
      fontSize: math.max(size, 1) * widget.scale,
      fontWeight: theme.typeScale.weightRegular,
      color: ramps.paper900,
    );
    final content = _content(theme, l10n, style);
    Widget result = DecoratedBox(
      decoration: decoration,
      child: field.readOnly
          ? CustomPaint(
              foregroundPainter: _DottedLine(
                color: ramps.paper400,
                width: width,
              ),
              child: content,
            )
          : content,
    );
    result = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        result,
        if (field.required && widget.first && !field.readOnly)
          PositionedDirectional(
            top: width - PdfFormField.asteriskTop,
            end: width - PdfFormField.asteriskEnd,
            child: ExcludeSemantics(
              child: Text(
                '*',
                style: theme.typography.body.copyWith(
                  fontSize: PdfFormField.asteriskFontSize,
                  fontWeight: theme.typeScale.weightSemibold,
                  color: page.formFieldRequired,
                ),
              ),
            ),
          ),
        if (widget.order case final order?)
          PositionedDirectional(
            top: -FormOverlay.orderTop,
            start: -FormOverlay.orderStart,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: FormOverlay.orderSize,
                  minHeight: FormOverlay.orderSize,
                ),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space0_5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.current
                      ? theme.colors.accent
                      : field.required
                      ? FermanRampTokens.ink700
                      : FermanRampTokens.paper600,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(PdfFormField.boxRadius),
                  ),
                ),
                child: Text(
                  format.integer(order),
                  style: theme.typography.label.copyWith(
                    color: page.pageBg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        if (error != null)
          PositionedDirectional(
            top: box.height * widget.scale + theme.space.space1,
            start: 0,
            child: Directionality(
              textDirection: widget.uiDirection,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space1,
                children: [
                  Icon(
                    IconName.circleAlert,
                    size: PdfFormField.smallIconSize,
                    color: ramps.red600,
                  ),
                  Text(
                    error,
                    style: theme.typography.caption.copyWith(
                      color: ramps.red600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    result = Popover(
      open: _menu || _picker,
      surface: false,
      onDismiss: _closePopups,
      anchor: result,
      child: Directionality(
        textDirection: widget.uiDirection,
        child: _picker ? _datePicker(context, l10n) : _choices(),
      ),
    );
    final label = field.label ?? field.name;
    return Semantics(
      label: label,
      textField: _typed,
      checked: switch (field.kind) {
        FieldKind.check ||
        FieldKind.radio => field.values.contains(widget.widget.onState),
        _ => null,
      },
      inMutuallyExclusiveGroup: field.kind == FieldKind.radio,
      button: field.kind == FieldKind.signature,
      readOnly: field.readOnly,
      hint: error,
      child: MouseRegion(
        cursor: field.readOnly
            ? MouseCursor.defer
            : _typed
            ? SystemMouseCursors.text
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: field.readOnly ? null : _pressed,
          child: Focus(
            focusNode: _typed ? null : _focus,
            onKeyEvent: _key,
            child: result,
          ),
        ),
      ),
    );
  }

  /// The value, its editor or its mark.
  Widget _content(FermanTheme theme, AppLocalizations l10n, TextStyle style) {
    final field = _field;
    final scaled = widget.scale;
    final padding = EdgeInsetsDirectional.symmetric(
      horizontal: PdfFormField.boxPaddingX / 2 * scaled,
    );
    final on = field.values.contains(widget.widget.onState ?? 'Yes');
    switch (field.kind) {
      case FieldKind.check:
        return on
            ? Center(
                child: Icon(
                  IconName.check,
                  size: widget.widget.rect.shortestSide * scaled * 0.8,
                  strokeWidth: PdfFormField.checkStroke,
                  color: theme.ramps.paper900,
                ),
              )
            : const SizedBox.expand();
      case FieldKind.radio:
        final size = widget.widget.rect.shortestSide * scaled * 0.5;
        return field.values.contains(widget.widget.onState)
            ? Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: theme.ramps.paper900,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : const SizedBox.expand();
      case FieldKind.signature:
        final signed = field.signed || field.signature != null;
        // The stamp of a simple signature draws itself on the page.
        if (signed) return const SizedBox.expand();
        return Padding(
          padding: padding,
          child: Row(
            spacing: theme.space.space1_5,
            children: [
              Icon(
                IconName.signature,
                size: PdfFormField.smallIconSize * scaled,
                color: theme.pageColors.formFieldFocus,
              ),
              Flexible(
                child: Text(
                  l10n.formSignHere,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: style.copyWith(
                    fontFamily: theme.typography.body.fontFamily,
                    color: theme.pageColors.formFieldFocus,
                  ),
                ),
              ),
            ],
          ),
        );
      case FieldKind.combo || FieldKind.list when !_typed:
        final shown = [
          for (final value in field.values)
            field.options
                    .where((option) => option.export == value)
                    .firstOrNull
                    ?.display ??
                value,
        ].join(', ');
        return Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: style,
                ),
              ),
              Icon(
                IconName.chevronDown,
                size: PdfFormField.smallIconSize * scaled,
                color: theme.ramps.paper500,
              ),
            ],
          ),
        );
      case _:
        final editing = widget.current && widget.first && widget.editable;
        final Widget text;
        if (editing) {
          text = Focus(
            onKeyEvent: _key,
            child: FieldInput(
              controller: _text,
              focusNode: _focus,
              style: style,
              obscureText: field.password,
              maxLines: field.multiline ? null : 1,
              inputFormatters: [
                if (field.maxLen case final most?)
                  LengthLimitingTextInputFormatter(most),
              ],
              placeholder: _isDate ? field.datePattern : null,
              placeholderColor: theme.ramps.paper500,
            ),
          );
        } else if (field.comb && field.maxLen != null) {
          final cells = field.maxLen!;
          final chars = _shown.characters.toList();
          text = Row(
            children: [
              for (var i = 0; i < cells; i++)
                Expanded(
                  child: Center(
                    child: Text(i < chars.length ? chars[i] : '', style: style),
                  ),
                ),
            ],
          );
        } else {
          text = Text(
            field.password ? '•' * _shown.characters.length : _shown,
            maxLines: field.multiline ? null : 1,
            overflow: TextOverflow.clip,
            style: style,
          );
        }
        return Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: field.multiline
                      ? AlignmentDirectional.topStart
                      : AlignmentDirectional.centerStart,
                  child: text,
                ),
              ),
              if (_isDate)
                GestureDetector(
                  onTap: widget.editable
                      ? () => setState(() => _picker = true)
                      : null,
                  child: Icon(
                    IconName.calendar,
                    size: PdfFormField.smallIconSize * scaled,
                    color: theme.ramps.paper500,
                  ),
                ),
              if (field.kind == FieldKind.combo)
                GestureDetector(
                  onTap: widget.editable
                      ? () => setState(() => _menu = true)
                      : null,
                  child: Icon(
                    IconName.chevronDown,
                    size: PdfFormField.smallIconSize * scaled,
                    color: theme.ramps.paper500,
                  ),
                ),
            ],
          ),
        );
    }
  }

  void _closePopups() => setState(() {
    _menu = false;
    _picker = false;
    _month = null;
  });

  /// A combo's or list's options, under the box.
  Widget _choices() {
    final field = _field;
    return Menu(
      semanticLabel: field.label ?? field.name,
      autofocus: true,
      items: [
        for (final option in field.options)
          MenuItem(
            id: option.export,
            label: option.display,
            checked: field.multiSelect
                ? field.values.contains(option.export)
                : null,
          ),
      ],
      onClose: () => setState(() => _menu = false),
      onSelected: (item) {
        setState(() => _menu = false);
        final id = item.id;
        if (id == null) return;
        final values = field.multiSelect
            ? (field.values.contains(id)
                  ? [
                      for (final value in field.values)
                        if (value != id) value,
                    ]
                  : [...field.values, id])
            : [id];
        _text.text = values.join(', ');
        _committed = _text.text;
        unawaited(_commands.setValue(field, values));
      },
    );
  }

  /// a5-2's calendar, under a date field, in the field's own format.
  Widget _datePicker(BuildContext context, AppLocalizations l10n) {
    final pattern = _field.datePattern ?? '';
    final region = ref.read(regionProvider);
    final month = _month ?? DateTime.now();
    void chosen(DateTime day) {
      _closePopups();
      _text.text = formatFieldDate(pattern, day);
      _committed = _text.text;
      unawaited(_commands.setValue(_field, [_text.text]));
    }

    return DatePicker(
      month: month,
      region: region.region,
      firstDayOfWeek: region.firstDayOfWeek.weekday,
      semanticLabel: l10n.formChooseDate,
      formatNote: l10n.formDateFormat(pattern),
      autofocus: true,
      onChanged: chosen,
      onDismiss: _closePopups,
      onMonthChanged: (next) => setState(() => _month = next),
      previousMonthButton: IconButton(
        icon: IconName.chevronLeft,
        label: l10n.formPreviousMonth,
        size: IconButtonSize.sm,
        onPressed: () =>
            setState(() => _month = DateTime(month.year, month.month - 1)),
      ),
      nextMonthButton: IconButton(
        icon: IconName.chevronRight,
        label: l10n.formNextMonth,
        size: IconButtonSize.sm,
        onPressed: () =>
            setState(() => _month = DateTime(month.year, month.month + 1)),
      ),
      todayButton: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => chosen(DateTime.now()),
        child: Text(l10n.formToday),
      ),
    );
  }
}

/// A read-only field's dotted line under its value (a5-2b).
class _DottedLine extends CustomPainter {
  const new({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += width * 2) {
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - width, width, width),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) =>
      old.color != color || old.width != width;
}
