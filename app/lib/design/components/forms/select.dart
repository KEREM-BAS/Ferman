import 'dart:math' as math;

import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/overlays/dialog.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// One option of a [Select] (the design-system `SelectOption`).
@immutable
class SelectOption<T> {
  /// Creates an option for [value], shown as [label].
  const new({
    required this.value,
    required this.label,
    this.disabled = false,
    this.disabledReason,
    this.locale,
  });

  /// The value the option stands for.
  final T value;

  /// The option's text.
  final String label;

  /// Whether the option cannot be chosen.
  final bool disabled;

  /// Why the option cannot be chosen (G10): its tooltip and semantics hint
  /// while [disabled]. Such an option stays reachable with the arrow keys,
  /// so the reason can be read; plain disabled options are skipped.
  final String? disabledReason;

  /// The locale of [label]'s text in the box and the list, so Han
  /// characters take their regional forms (a language's own name, "繁體中文",
  /// or a region's, "台灣"); null takes the surrounding text's. It steers
  /// font fallback only, never the direction. Not a design-system prop.
  final Locale? locale;

  @override
  bool operator ==(Object other) =>
      other is SelectOption<T> &&
      other.value == value &&
      other.label == label &&
      other.disabled == disabled &&
      other.disabledReason == disabledReason &&
      other.locale == locale;

  @override
  int get hashCode =>
      Object.hash(value, label, disabled, disabledReason, locale);

  @override
  String toString() => 'SelectOption($value, $label)';
}

/// A field-styled picker of one option, the design-system `Select`
/// component (`components/forms/Select.jsx`, `.fm-select`).
///
/// The box is a [Field] box of [size] showing [icon] (14 or 16 px), the
/// label of the option whose value is [value], and a trailing
/// `chevron-down`; [label] sits above it. The bundle restyles a native
/// `<select>` whose open list is not drawn; here the list opens in a
/// [Popover] under the box, at least as wide as it, in the Menu item look
/// (28 px rows, the strong selection tint on the highlighted row, a check
/// in the secondary icon colour on the chosen one) (COMPONENTS.md decision
/// 8). Never a Material
/// dropdown.
///
/// The widget is controlled: choosing an option calls [onChanged] with its
/// value and closes the list; the owner passes the new [value].
///
/// **Pointer.** A click on the box opens the list, or closes it without a
/// change; the box takes focus, as a native `<select>` does. The pointer
/// moves the highlight over enabled options only (`.fm-menu__item:disabled`
/// takes no hover tint).
///
/// **Keyboard.** Enter, Space or Alt+ArrowDown open the list; ArrowUp and
/// ArrowDown move the highlight, skipping plain disabled options and
/// stopping on options disabled with a reason; Enter or Space choose the
/// highlighted option; Escape (or a click outside) closes without a
/// change. Focus stays on the box throughout, which shows the field focus
/// ring while it has keyboard focus or the list is open. The list opens
/// scrolled to the chosen option and scrolls only as far as the highlight
/// needs.
///
/// **Disabled.** [disabled] gives the disabled field look and no input;
/// with [disabledReason] the box stays focusable and shows the reason as
/// its tooltip and semantics hint (G10).
///
/// For screen readers the box is a button named by [label] (or
/// [semanticLabel]) whose value is the chosen option's label, expanded
/// while the list is open. The open list is a menu of the same name whose
/// options are radio menu items, the chosen one checked (Flutter has no
/// listbox role).
class Select<T> extends StatefulWidget {
  /// Creates a select over [options].
  const new({
    required this.options,
    super.key,
    this.label,
    this.value,
    this.onChanged,
    this.size = FieldSize.md,
    this.icon,
    this.disabled = false,
    this.disabledReason,
    this.semanticLabel,
    this.focusNode,
    this.menu,
    this.onMenuSelected,
    this.onTyped,
    this.typingHint,
  });

  /// The label above the box; null shows none.
  final String? label;

  /// The options, in order.
  final List<SelectOption<T>> options;

  /// The chosen value; null (or a value no option has) shows an empty box.
  final T? value;

  /// Called with the value of the option the user chooses; null disables
  /// the select.
  final ValueChanged<T>? onChanged;

  /// The height, padding and text size of the box.
  final FieldSize size;

  /// The leading icon (`languages` for the app language); null shows none.
  final IconName? icon;

  /// Whether the select is disabled.
  final bool disabled;

  /// Why the select is disabled: its tooltip and semantics hint while
  /// disabled (G10).
  final String? disabledReason;

  /// The accessible name when no [label] is shown (`aria-label`: the zoom
  /// and sort selects).
  final String? semanticLabel;

  /// The focus node of the box; one is created when null. Not a
  /// design-system prop.
  final FocusNode? focusNode;

  /// A [Menu] that opens instead of the list (a2-2's zoom menu, with the
  /// fits' shortcuts, separators and Marquee zoom); the box still shows
  /// the label of [value]'s option. Not a design-system prop.
  final List<MenuItem>? menu;

  /// Called with the item of [menu] the user activates.
  final ValueChanged<MenuItem>? onMenuSelected;

  /// Called with the text the user typed, once they finish (Enter or
  /// leaving the box; Escape drops it). Non-null makes the box take typing
  /// (a2-2's zoom field): a digit key, on the box or in its open list or
  /// menu, turns the box into a text field holding that digit. A click still
  /// opens the list or menu. Not a design-system prop.
  final ValueChanged<String>? onTyped;

  /// What a screen reader says the box takes while [onTyped] is set.
  final String? typingHint;

  /// `.fm-menu__item` `height`: a row of the open list.
  static const double rowHeight = 28;

  /// The tallest the open list grows before it scrolls (`.fm-fontpop`
  /// `max-height`, the nearest drawn list).
  static const double maxListHeight = 340;

  /// `.fm-select` `padding-inline-end`.
  static const double endPadding = 4;

  /// a13-8c: a list of more options than this has a search field.
  static const int searchThreshold = 8;

  /// a13-8c: a row of the bottom sheet (`min-height: 56px`).
  static const double sheetRowHeight = 56;

  /// a13-8c: the row's side padding (`padding: 0 24px`).
  static const double sheetRowSide = 24;

  /// a13-8c: the row's text (`font: 400 16px/1`).
  static const double sheetRowTextSize = 16;

  /// a13-8c: the check at the row's end (`size={{ 22 }}`).
  static const double sheetCheckSize = 22;

  /// a13-8c: the gap in the row (`gap: 16px`).
  static const double sheetRowGap = 16;

  @override
  State<Select<T>> createState() => _SelectState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(IterableProperty<SelectOption<T>>('options', options))
      ..add(DiagnosticsProperty<T>('value', value, defaultValue: null))
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.md))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      )
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

class _SelectState<T> extends State<Select<T>> {
  bool _open = false;
  int _highlight = -1;
  FocusNode? _ownNode;
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  /// What the bottom sheet's search field holds (a13-8c).
  final TextEditingController _query = TextEditingController();

  /// A decimal digit of any script, as the region may write its own.
  static final RegExp _digit = RegExp(r'^\p{Nd}$', unicode: true);

  bool _typing = false;
  final TextEditingController _draft = TextEditingController();
  final FocusNode _draftNode = FocusNode(debugLabel: 'Select draft');

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'Select'));

  bool get _enabled => !widget.disabled && widget.onChanged != null;

  int get _selectedIndex =>
      widget.options.indexWhere((option) => option.value == widget.value);

  @override
  void initState() {
    super.initState();
    _draftNode.addListener(_onDraftFocus);
  }

  @override
  void didUpdateWidget(Select<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _open) _open = false;
    if (!_enabled || widget.onTyped == null) _typing = false;
    if (_highlight >= widget.options.length) _highlight = -1;
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    _scroll.dispose();
    _query.dispose();
    _draftNode
      ..removeListener(_onDraftFocus)
      ..dispose();
    _draft.dispose();
    super.dispose();
  }

  /// The digit [event] types into the box, or null.
  String? _typedDigit(KeyEvent event) {
    if (event is! KeyDownEvent || widget.onTyped == null || !_enabled) {
      return null;
    }
    final keys = HardwareKeyboard.instance;
    // ⌘1 and its like belong to the shortcut table.
    if (keys.isMetaPressed || keys.isControlPressed || keys.isAltPressed) {
      return null;
    }
    final character = event.character;
    return character != null && _digit.hasMatch(character) ? character : null;
  }

  void _startTyping(String digit) {
    _draft.value = TextEditingValue(
      text: digit,
      selection: TextSelection.collapsed(offset: digit.length),
    );
    setState(() {
      _open = false;
      _typing = true;
    });
    // The field exists from the next frame on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _typing) _draftNode.requestFocus();
    });
  }

  void _endTyping({required bool commit, required bool refocus}) {
    if (!_typing) return;
    setState(() => _typing = false);
    if (refocus) {
      // The box is back from the next frame on.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
    if (commit) widget.onTyped?.call(_draft.text);
  }

  /// Leaving the field finishes the typing, as a stepper's draft does.
  void _onDraftFocus() {
    if (!_draftNode.hasFocus) _endTyping(commit: true, refocus: false);
  }

  /// Whether the highlight can rest on the option at [index]: enabled
  /// options and options disabled with a reason.
  bool _reachable(int index) {
    final option = widget.options[index];
    return _matches(option) &&
        (!option.disabled || option.disabledReason != null);
  }

  /// Whether the bottom sheet's search keeps [option]; always without a
  /// search, as on a desktop, including when an open list has just widened
  /// past the phone width and shows every row. The language's casing finds
  /// "İstanbul" from "ist" in Turkish; the root casing finds Latin names such
  /// as "Italiano" from "ita" there, as the first-run picker does.
  bool _matches(SelectOption<T> option) {
    final query = _query.text.trim();
    if (query.isEmpty || !WindowMetrics.isPhone(context)) return true;
    final casing = LocaleCasing.of(context);
    const root = LocaleCasing.root;
    final queries = {casing.lower(query), root.lower(query)};
    return [
      casing.lower(option.label),
      root.lower(option.label),
    ].any((label) => queries.any(label.contains));
  }

  /// The search changed: keeps the highlight on a row still shown.
  void _onQueryChanged(String _) => setState(() {
    if (_highlight < 0 ||
        _highlight >= widget.options.length ||
        !_matches(widget.options[_highlight])) {
      _highlight = _step(-1, 1);
    }
  });

  void _openList() {
    if (!_enabled || _open) return;
    _query.clear();
    // A click opens the list too, and the keys go to the box from then on.
    _node.requestFocus();
    final selected = _selectedIndex;
    setState(() {
      _open = true;
      _highlight = selected >= 0 ? selected : _step(-1, 1);
    });
    // The rows are built when the popover shows, a frame later; the list
    // reveals the highlight once it is mounted (_OnMount).
  }

  /// A click on the box (and a screen reader's tap): opens or closes the
  /// list, never choosing.
  void _toggle() => _open ? _close() : _openList();

  void _close({bool refocus = true}) {
    if (!_open) return;
    setState(() => _open = false);
    if (refocus) _node.requestFocus();
  }

  /// The next reachable index after [from] in [direction], or [from] when
  /// there is none.
  int _step(int from, int direction) {
    var index = from + direction;
    while (index >= 0 && index < widget.options.length) {
      if (_reachable(index)) return index;
      index += direction;
    }
    return from;
  }

  void _move(int direction) {
    final from = _highlight;
    final next = _step(from, direction);
    if (next == from) return;
    setState(() => _highlight = next);
    _reveal();
  }

  /// Scrolls the highlighted row into view after the frame, only as far as
  /// it needs: not at all when it is in view, else to the edge it lies
  /// past, on either side (the list may have been scrolled away from it
  /// without moving it).
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _highlight < 0 || _highlight >= _rowKeys.length) return;
      final row = _rowKeys[_highlight].currentContext;
      if (row == null || !row.mounted) return;
      // One of the two does nothing: the first only scrolls down to a row
      // below the view, the second only up to a row above it.
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _choose(int index) {
    if (index < 0 || index >= widget.options.length) return;
    final option = widget.options[index];
    // Or a row the search hides, after a window narrowed under an open list.
    if (option.disabled || !_matches(option)) return;
    _close();
    widget.onChanged?.call(option.value);
  }

  void _activate() {
    if (_open) {
      _choose(_highlight);
    } else {
      _openList();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_typedDigit(event) case final digit?) {
      _startTyping(digit);
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (!_open) {
      final alt = HardwareKeyboard.instance.isAltPressed;
      if (alt && key == LogicalKeyboardKey.arrowDown && _enabled) {
        _openList();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      // -1 when no option can take the highlight.
      setState(() => _highlight = _step(-1, 1));
      _reveal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      final last = _step(widget.options.length, -1);
      // The length itself when no option can take the highlight.
      if (last < widget.options.length) {
        setState(() => _highlight = last);
        _reveal();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _close(refocus: false);
    }
    return KeyEventResult.ignored;
  }

  /// The keys inside the bottom sheet, where focus has left the box: Enter
  /// chooses, and Space too unless it is typed into the search.
  KeyEventResult _onSheetKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          (key == LogicalKeyboardKey.space &&
              widget.options.length <= Select.searchThreshold)) {
        _choose(_highlight);
        return KeyEventResult.handled;
      }
    }
    return _onKey(node, event);
  }

  /// The list as the phone's bottom sheet draws it (a13-8c, G129): a search
  /// field over more than [Select.searchThreshold] options, and tall rows.
  Widget _sheetList(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    while (_rowKeys.length < widget.options.length) {
      _rowKeys.add(GlobalKey(debugLabel: 'Select row ${_rowKeys.length}'));
    }
    final selected = _selectedIndex;
    final name = widget.label ?? widget.semanticLabel;
    final shown = [
      for (var i = 0; i < widget.options.length; i++)
        if (_matches(widget.options[i])) i,
    ];
    return _OnMount(
      onMount: _reveal,
      // Takes focus when the sheet opens, so the keys arrive without a
      // keyboard popping up for the search.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onSheetKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.options.length > Select.searchThreshold)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Dialog.sheetTitleSide,
                  0,
                  Dialog.sheetTitleSide,
                  Dialog.sheetTitleBottom,
                ),
                child: TextField(
                  controller: _query,
                  icon: IconName.search,
                  placeholder: l10n.selectSheetSearch,
                  semanticLabel: l10n.selectSheetSearch,
                  onChanged: _onQueryChanged,
                ),
              ),
            Flexible(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                role: shown.isEmpty ? null : SemanticsRole.menu,
                label: name,
                child: shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsetsDirectional.all(
                          Select.sheetRowSide,
                        ),
                        child: Text(
                          l10n.selectSheetNoMatch,
                          style: theme.typography.body.copyWith(
                            color: theme.colors.textSecondary,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scroll,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final i in shown)
                              _SelectRow(
                                key: _rowKeys[i],
                                sheet: true,
                                option: widget.options[i],
                                selected: i == selected,
                                highlighted: i == _highlight,
                                onHover: () {
                                  if (!widget.options[i].disabled &&
                                      _highlight != i) {
                                    setState(() => _highlight = i);
                                  }
                                },
                                onPressed: () => _choose(i),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final disabled = states.contains(WidgetState.disabled);
    final selected = _selectedIndex;
    final icon = widget.icon;
    final text = selected >= 0 ? widget.options[selected].label : '';
    final textLocale = selected >= 0 ? widget.options[selected].locale : null;
    // `.fm-input > svg { color: var(--icon-secondary) }` sets the colour on
    // the svg itself, so `.fm-input--disabled` does not reach it.
    final iconColor = colors.iconSecondary;
    return FieldBox(
      size: widget.size,
      disabled: disabled,
      focused: states.contains(WidgetState.focused) || _open,
      hovered: states.contains(WidgetState.hovered),
      padding: EdgeInsetsDirectional.only(
        start: FieldBox.sidePaddingOf(theme, widget.size),
        end: Select.endPadding,
      ),
      child: Row(
        spacing: FieldBox.contentGap,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: FieldBox.iconSizeOf(theme, widget.size),
              color: iconColor,
            ),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: textLocale == null
                    ? null
                    : DefaultTextStyle.of(context).style
                          .copyWith(locale: textLocale),
              ),
            ),
          ),
          Icon(
            IconName.chevronDown,
            size: theme.density.iconSm,
            color: iconColor,
          ),
        ],
      ),
    );
  }

  /// The box while it takes typing: the same box with the same chevron, its
  /// text a field.
  Widget _typingBox(BuildContext context) {
    final theme = context.ferman;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        _endTyping(commit: false, refocus: true);
        return KeyEventResult.handled;
      },
      child: FieldBox(
        size: widget.size,
        focused: true,
        padding: EdgeInsetsDirectional.only(
          start: FieldBox.sidePaddingOf(theme, widget.size),
          end: Select.endPadding,
        ),
        child: Row(
          spacing: FieldBox.contentGap,
          children: [
            Expanded(
              child: Semantics(
                label: widget.label ?? widget.semanticLabel,
                hint: widget.typingHint,
                child: FieldInput(
                  controller: _draft,
                  focusNode: _draftNode,
                  style: FieldBox.textStyleOf(
                    theme,
                    widget.size,
                    color: theme.colors.textPrimary,
                  ),
                  onEditingComplete: () =>
                      _endTyping(commit: true, refocus: true),
                ),
              ),
            ),
            Icon(
              IconName.chevronDown,
              size: theme.density.iconSm,
              color: theme.colors.iconSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final theme = context.ferman;
    while (_rowKeys.length < widget.options.length) {
      _rowKeys.add(GlobalKey(debugLabel: 'Select row ${_rowKeys.length}'));
    }
    final selected = _selectedIndex;
    final name = widget.label ?? widget.semanticLabel;
    final list = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: Select.maxListHeight),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsetsDirectional.all(theme.space.space1),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.options.length; i++)
                _SelectRow(
                  key: _rowKeys[i],
                  option: widget.options[i],
                  selected: i == selected,
                  highlighted: i == _highlight,
                  onHover: () {
                    // The pointer tints enabled options only; the keyboard
                    // also stops on options disabled with a reason.
                    if (!widget.options[i].disabled && _highlight != i) {
                      setState(() => _highlight = i);
                    }
                  },
                  onPressed: () => _choose(i),
                ),
            ],
          ),
        ),
      ),
    );
    return _OnMount(
      onMount: _reveal,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        scopesRoute: true,
        namesRoute: name != null,
        // Flutter has no listbox role; a menu must not be empty.
        role: widget.options.isEmpty ? null : SemanticsRole.menu,
        label: name,
        child: list,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final selected = _selectedIndex;
    final box = _typing
        ? _typingBox(context)
        : Focus(
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            onKeyEvent: _onKey,
            child: FermanInteractive(
              onPressed: _enabled ? _activate : null,
              onTap: _enabled ? _toggle : null,
              disabled: widget.disabled,
              disabledReason: widget.disabledReason,
              semanticLabel: label ?? widget.semanticLabel,
              focusNode: _node,
              builder: (context, states, _) => Semantics(
                expanded: _open,
                value: selected >= 0 ? widget.options[selected].label : null,
                // The highlighted option's reason, while the list is open
                // (G10).
                hint:
                    _open &&
                        _highlight >= 0 &&
                        _highlight < widget.options.length &&
                        widget.options[_highlight].disabled
                    ? widget.options[_highlight].disabledReason
                    : widget.typingHint,
                child: _box(context, states),
              ),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Field.gap,
      children: [
        if (label != null) Field.labelOf(context, label),
        if (WindowMetrics.isPhone(context) && widget.menu == null)
          Stack(
            fit: StackFit.passthrough,
            children: [
              box,
              Dialog(
                open: _open,
                sheet: true,
                title: label ?? widget.semanticLabel ?? '',
                onClose: _close,
                closeLabel: AppLocalizations.of(context).selectSheetClose,
                child: _sheetList(context),
              ),
            ],
          )
        else if (widget.menu case final menu?)
          Popover(
            open: _open,
            surface: false,
            onDismiss: _close,
            anchor: box,
            // The menu has the focus while it is open; a digit it does not
            // want reaches this box's typing.
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              includeSemantics: false,
              onKeyEvent: (_, event) {
                final digit = _typedDigit(event);
                if (digit == null) return KeyEventResult.ignored;
                _startTyping(digit);
                return KeyEventResult.handled;
              },
              child: Menu(
                autofocus: true,
                semanticLabel: label ?? widget.semanticLabel,
                items: menu,
                onClose: _close,
                onSelected: (item) {
                  _close();
                  widget.onMenuSelected?.call(item);
                },
              ),
            ),
          )
        else
          Popover(
            open: _open,
            matchAnchorWidth: true,
            onDismiss: _close,
            anchor: box,
            child: _list(context),
          ),
      ],
    );
  }
}

/// A row of the open list, in the Menu item look (`.fm-menu__item`).
class _SelectRow extends StatelessWidget {
  const new({
    required this.option,
    required this.selected,
    required this.highlighted,
    required this.onHover,
    required this.onPressed,
    super.key,
    this.sheet = false,
  });

  /// Whether the row sits in the phone's bottom sheet (a13-8c).
  final bool sheet;

  final SelectOption<Object?> option;
  final bool selected;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final disabled = option.disabled;
    final reason = disabled ? option.disabledReason : null;
    Widget row = Semantics(
      container: true,
      button: true,
      role: SemanticsRole.menuItemRadio,
      checked: selected,
      selected: selected,
      enabled: !disabled,
      label: option.label,
      hint: reason,
      onTap: disabled ? null : onPressed,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) => onHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: disabled ? null : onPressed,
            child: sheet
                ? _sheetRow(theme)
                : Container(
                    height: math.max(Select.rowHeight, theme.density.hitMin),
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: theme.space.space2,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted ? colors.surfaceSelectedStrong : null,
                      borderRadius: BorderRadius.all(
                        Radius.circular(theme.radius.radiusSm),
                      ),
                    ),
                    child: Row(
                      spacing: theme.space.space2,
                      children: [
                        SizedBox(
                          width: theme.density.iconSm,
                          child: selected
                              ? Icon(
                                  IconName.check,
                                  size: theme.density.iconSm,
                                  strokeWidth: 2,
                                  // The Menu check: `.fm-menu__item svg`
                                  // colours it, over the span's accent (G78).
                                  color: disabled
                                      ? colors.iconDisabled
                                      : colors.iconSecondary,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            option.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.copyWith(
                              color: disabled
                                  ? colors.textDisabled
                                  : colors.textPrimary,
                              locale: option.locale,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
    if (reason != null) {
      // Open while the keyboard highlight rests on the row, so the reason
      // can be read without a pointer (G10).
      row = Tooltip(
        message: reason,
        side: sheet ? TooltipSide.top : TooltipSide.right,
        open: highlighted ? true : null,
        excludeFromSemantics: true,
        opensOnTouch: sheet,
        child: row,
      );
    }
    return row;
  }

  /// The row of a13-8c: the label, which may wrap, and the check at the end,
  /// on the accent's tint when selected.
  Widget _sheetRow(FermanTheme theme) {
    final colors = theme.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: Select.sheetRowHeight),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Select.sheetRowSide,
      ),
      color: selected
          ? colors.accentSubtle
          : highlighted
          ? colors.surfaceSelectedStrong
          : null,
      child: Row(
        spacing: Select.sheetRowGap,
        children: [
          Expanded(
            child: Text(
              option.label,
              style: theme.typography.body.copyWith(
                color: option.disabled
                    ? colors.textDisabled
                    : colors.textPrimary,
                fontSize: Select.sheetRowTextSize,
                locale: option.locale,
              ),
            ),
          ),
          if (selected)
            Icon(
              IconName.check,
              size: Select.sheetCheckSize,
              color: colors.textAccent,
            ),
        ],
      ),
    );
  }
}

/// Runs [onMount] when the open list is first built, the frame its rows
/// appear in (the popover builds its content only once it shows).
class _OnMount extends StatefulWidget {
  const new({required this.onMount, required this.child});

  final VoidCallback onMount;
  final Widget child;

  @override
  State<_OnMount> createState() => _OnMountState();
}

class _OnMountState extends State<_OnMount> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
