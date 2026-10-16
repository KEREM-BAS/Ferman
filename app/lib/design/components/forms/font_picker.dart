import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// Where a font of a [FontPicker] comes from (`FontOption.group`).
enum FontGroup {
  /// Used in the open document ("In this document").
  document,

  /// Installed on this device ("On this device").
  system,
}

/// One font of a [FontPicker] (the design-system `FontOption`).
@immutable
class FontOption {
  /// Creates a font entry called [name].
  const new({
    required this.name,
    this.family,
    this.available = true,
    this.substitute,
    this.group = FontGroup.system,
  });

  /// The font's name, shown and reported.
  final String name;

  /// The family to draw the name in; null draws it in [name].
  final String? family;

  /// Whether the font is installed; a missing font draws its name in the
  /// UI font and gets the "Not installed" badge.
  final bool available;

  /// The font shown instead of a missing one, for the missing-font note.
  final String? substitute;

  /// The section the font is listed in.
  final FontGroup group;

  @override
  bool operator ==(Object other) =>
      other is FontOption &&
      other.name == name &&
      other.family == family &&
      other.available == available &&
      other.substitute == substitute &&
      other.group == group;

  @override
  int get hashCode => Object.hash(name, family, available, substitute, group);

  @override
  String toString() => 'FontOption($name)';
}

/// A font trigger with a searchable popover grouped by origin and a
/// missing-font warning, the design-system `FontPicker` component
/// (`components/forms/FontPicker.jsx`, `.fm-fonttrigger`, `.fm-fontpop`).
///
/// The trigger is a [Field] box of [size] with [label] above, showing the
/// current font's name ([value]) in that font at 13 px and a
/// `chevron-down`. When the current font is not installed the name turns
/// italic secondary text in the UI font, a `triangle-alert` leads, the
/// border takes the warning colour, and a note under the trigger says so
/// ([missingNote], or [warning] which overrides it): Ferman never
/// substitutes silently (ADR 0006). [glyphWarning] (DS additions fix 2,
/// G36) gives the amber border and triangle in the trigger only; its
/// border stays amber with focus and when disabled
/// (`[data-fm-glyph-warning] .fm-fonttrigger` wins over both).
///
/// Enter, Space or a click toggle the popover (280 px, at most 340 px tall,
/// `.fm-fontpop`): a search field that takes focus, then the matching
/// [fonts] in two sections ([documentGroupLabel], [systemGroupLabel]),
/// each row a check for the current font, the name drawn in its family
/// (14 px) and, for a missing font, [missingBadge]. With no match the
/// popover shows [noMatchesText] for the query. ArrowDown and ArrowUp move
/// between the search field and the rows, stopping at the ends (not in the
/// bundle; the listbox pattern its roles imply); Tab and Shift+Tab cycle
/// through them. Focus stays in the popover, which is a focus scope of its
/// own, so it never reaches the controls the popover covers. Enter or a
/// click choose a font and close; Escape or a click outside close. Focus
/// returns to the trigger, except after a click that opened the popover
/// and then chose a font or closed it, which leaves no focus ring (G22).
/// Matching follows the casing rules of the UI language ([LocaleCasing]).
///
/// The fonts are passed in: M1 does not enumerate system fonts. The open
/// state is [open] when given (requests through [onOpenChanged]), else
/// local from [initiallyOpen]; the font is controlled ([onChanged]).
///
/// For screen readers the trigger is a button named by [label] whose value
/// is the font, expanded while open; the rows are buttons named by the
/// font, selected for the current one, in a list named by
/// [listSemanticLabel].
class FontPicker extends StatefulWidget {
  /// Creates a font picker showing [value].
  const new({
    required this.value,
    super.key,
    this.label,
    this.fonts = const [],
    this.warning,
    this.open,
    this.initiallyOpen = false,
    this.onOpenChanged,
    this.onChanged,
    this.size = FieldSize.sm,
    this.disabled = false,
    this.glyphWarning = false,
    this.disabledReason,
    this.missingNote,
    this.missingBadge,
    this.documentGroupLabel,
    this.systemGroupLabel,
    this.searchPlaceholder,
    this.searchSemanticLabel,
    this.listSemanticLabel,
    this.noMatchesText,
    this.focusNode,
  });

  /// `.fm-fontpop` `width`.
  static const double popoverWidth = 280;

  /// `.fm-fontpop` `max-height`.
  static const double popoverMaxHeight = 340;

  /// `.fm-fontrow` `height`.
  static const double rowHeight = 30;

  /// `[data-fm-glyph-warning] .fm-fonttrigger::before`: the triangle's
  /// stroke.
  static const double glyphWarningStroke = 1.8;

  /// The label above the trigger; null shows none.
  final String? label;

  /// The current font's name.
  final String value;

  /// The fonts to offer.
  final List<FontOption> fonts;

  /// The note under the trigger, overriding [missingNote]; null shows the
  /// missing-font note when the current font is missing.
  final String? warning;

  /// Whether the popover is open; null keeps the state locally.
  final bool? open;

  /// Whether a locally kept popover starts open (the DS `defaultOpen`).
  final bool initiallyOpen;

  /// Called when the popover asks to open or close.
  final ValueChanged<bool>? onOpenChanged;

  /// Called with the chosen font's name; null disables the picker.
  final ValueChanged<String>? onChanged;

  /// The height and padding of the trigger.
  final FieldSize size;

  /// Whether the picker is disabled.
  final bool disabled;

  /// Whether the trigger shows the glyph warning: the amber border and a
  /// triangle, with the message in the panel's callout (fix 2, G36).
  final bool glyphWarning;

  /// Why the picker is disabled (G10). Not a design-system prop.
  final String? disabledReason;

  /// The note shown when the current font is not installed ("Minion Pro
  /// isn't installed. Ferman is showing Source Serif instead."), built by
  /// the screen from the font and its substitute. Not a design-system
  /// prop: the bundle builds it in English.
  final String? missingNote;

  /// The badge on missing fonts' rows (a warning Badge "Not installed");
  /// null shows none.
  final Widget? missingBadge;

  /// The heading of the document's fonts ("In this document").
  final String? documentGroupLabel;

  /// The heading of the device's fonts ("On this device").
  final String? systemGroupLabel;

  /// The search field's placeholder ("Search fonts").
  final String? searchPlaceholder;

  /// The search field's accessible name ("Search fonts").
  final String? searchSemanticLabel;

  /// The list's accessible name ("Fonts").
  final String? listSemanticLabel;

  /// The text shown when no font matches the query ("No fonts match
  /// “query”.").
  final String Function(String query)? noMatchesText;

  /// The focus node of the trigger; one is created when null.
  final FocusNode? focusNode;

  @override
  State<FontPicker> createState() => _FontPickerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(StringProperty('value', value))
      ..add(IterableProperty<FontOption>('fonts', fonts))
      ..add(StringProperty('warning', warning, defaultValue: null))
      ..add(
        FlagProperty('open', value: open, ifTrue: 'open', ifFalse: 'closed'),
      )
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.sm))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        FlagProperty(
          'glyphWarning',
          value: glyphWarning,
          ifTrue: 'glyph warning',
        ),
      );
  }
}

class _FontPickerState extends State<FontPicker> {
  late bool _localOpen = widget.initiallyOpen;

  /// Whether a click (or a screen reader's tap) on the trigger opened the
  /// popover.
  bool _pointerOpened = false;
  FocusNode? _ownNode;
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchNode = FocusNode(debugLabel: 'FontPicker search');

  /// The popover's own focus scope: the arrows and Tab stay among the
  /// search field and the rows.
  final FocusScopeNode _listScope = FocusScopeNode(
    debugLabel: 'FontPicker list',
  );

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'FontPicker'));

  bool get _enabled => !widget.disabled && widget.onChanged != null;

  bool get _open => _enabled && (widget.open ?? _localOpen);

  FontOption get _current => widget.fonts.firstWhere(
    (font) => font.name == widget.value,
    orElse: () => FontOption(name: widget.value),
  );

  @override
  void dispose() {
    _ownNode?.dispose();
    _query.dispose();
    _searchNode.dispose();
    _listScope.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FontPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_open) _pointerOpened = false;
  }

  void _setOpen(bool open) {
    if (open) _query.clear();
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

  /// Chooses [font] and closes; focus returns to the trigger unless a
  /// click both opened the popover and chose the font ([pointer]).
  void _choose(FontOption font, {required bool pointer}) {
    final refocus = !(pointer && _pointerOpened);
    _setOpen(false);
    if (refocus) _node.requestFocus();
    widget.onChanged?.call(font.name);
  }

  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return KeyEventResult.ignored;
    // Inside the popover's scope, so the move stops at its ends
    // (directional edge behaviour `stop`).
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      focus.focusInDirection(TraversalDirection.down);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      focus.focusInDirection(TraversalDirection.up);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _trigger(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final current = _current;
    final missing = !current.available;
    final disabled = states.contains(WidgetState.disabled);
    final warn = missing || widget.glyphWarning;
    final ui = theme.typography.body;
    return FieldBox(
      size: widget.size,
      disabled: disabled,
      warning: warn,
      warningOverridesState: widget.glyphWarning,
      focused: states.contains(WidgetState.focused),
      hovered: states.contains(WidgetState.hovered),
      focusRingStyle: FocusRingStyle.outer,
      child: Row(
        spacing: FieldBox.contentGap,
        children: [
          if (warn)
            Icon(
              IconName.triangleAlert,
              size: theme.density.iconSm,
              strokeWidth: missing
                  ? Icon.defaultStrokeWidth
                  : FontPicker.glyphWarningStroke,
              color: colors.warningSolid,
            ),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                current.name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: missing
                      ? ui.fontFamily
                      : current.family ?? current.name,
                  fontFamilyFallback: ui.fontFamilyFallback,
                  fontSize: theme.typeScale.sizeMd,
                  fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                  color: disabled
                      ? colors.textDisabled
                      : (missing ? colors.textSecondary : colors.textPrimary),
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

  Widget _popover(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final casing = LocaleCasing.of(context);
    final query = casing.lower(_query.text);
    final filtered = [
      for (final font in widget.fonts)
        if (casing.lower(font.name).contains(query)) font,
    ];
    final sections = <Widget>[];
    for (final (group, title) in [
      (FontGroup.document, widget.documentGroupLabel),
      (FontGroup.system, widget.systemGroupLabel),
    ]) {
      final items = [
        for (final font in filtered)
          if (font.group == group) font,
      ];
      if (items.isEmpty) continue;
      if (title != null) sections.add(PopoverSection(title));
      for (final font in items) {
        sections.add(
          _FontRow(
            font: font,
            selected: font.name == widget.value,
            badge: widget.missingBadge,
            onPressed: () => _choose(font, pointer: false),
            onTap: () => _choose(font, pointer: true),
          ),
        );
      }
    }
    final noMatches = widget.noMatchesText;
    return Semantics(
      label: widget.listSemanticLabel,
      explicitChildNodes: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onListKey,
        child: FocusScope(
          node: _listScope,
          child: FocusTraversalGroup(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: FontPicker.popoverWidth,
                minWidth: FontPicker.popoverWidth,
                maxHeight: FontPicker.popoverMaxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      theme.space.space2,
                      theme.space.space2,
                      theme.space.space2,
                      theme.space.space0_5,
                    ),
                    child: _FocusOnMount(
                      node: _searchNode,
                      child: TextField(
                        size: FieldSize.sm,
                        icon: IconName.search,
                        controller: _query,
                        focusNode: _searchNode,
                        placeholder: widget.searchPlaceholder,
                        semanticLabel: widget.searchSemanticLabel,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsetsDirectional.only(
                        bottom: theme.space.space1_5,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...sections,
                          if (filtered.isEmpty && noMatches != null)
                            Padding(
                              padding: EdgeInsetsDirectional.symmetric(
                                horizontal: theme.space.space3,
                                vertical: theme.space.space2_5,
                              ),
                              child: Text(
                                noMatches(_query.text),
                                style: theme.typography.caption.copyWith(
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                        ],
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final label = widget.label;
    final open = _open;
    final current = _current;
    final note =
        widget.warning ?? (current.available ? null : widget.missingNote);
    final trigger = FermanInteractive(
      onPressed: _enabled ? () => _toggle(pointer: false) : null,
      onTap: _enabled ? () => _toggle(pointer: true) : null,
      disabled: widget.disabled,
      disabledReason: widget.disabledReason,
      semanticLabel: label,
      focusNode: _node,
      builder: (context, states, _) => Semantics(
        expanded: open,
        value: current.name,
        hint: note,
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
            child: _popover(context),
          ),
        ),
        if (note != null)
          // Its own node, the bundle's `role="status"` note.
          Semantics(
            container: true,
            liveRegion: true,
            label: note,
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.space.space1_5,
                children: [
                  Padding(
                    // `.fm-fontnote svg { margin-top: 1px }`.
                    padding: const EdgeInsetsDirectional.only(top: 1),
                    child: Icon(
                      IconName.triangleAlert,
                      size: theme.density.iconSm,
                      color: theme.colors.warningSolid,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      note,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One row of the font list (`.fm-fontrow`).
class _FontRow extends StatelessWidget {
  const new({
    required this.font,
    required this.selected,
    required this.badge,
    required this.onPressed,
    required this.onTap,
  });

  final FontOption font;
  final bool selected;
  final Widget? badge;

  /// Enter or Space on the row.
  final VoidCallback onPressed;

  /// A click or a screen reader's tap on the row.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final missing = !font.available;
    final ui = theme.typography.body;
    final mark = badge;
    return FermanInteractive(
      onPressed: onPressed,
      onTap: onTap,
      selected: selected,
      semanticLabel: font.name,
      builder: (context, states, _) {
        final tinted =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused);
        return Container(
          height: FontPicker.rowHeight,
          padding: EdgeInsetsDirectional.only(
            start: theme.space.space2,
            end: theme.space.space2_5,
          ),
          color: tinted ? colors.surfaceHover : null,
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
                        color: colors.textAccent,
                      )
                    : null,
              ),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    font.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: missing
                          ? ui.fontFamily
                          : font.family ?? font.name,
                      fontFamilyFallback: ui.fontFamilyFallback,
                      fontSize: theme.typeScale.sizeLg,
                      color: missing
                          ? colors.textSecondary
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (missing && mark != null) mark,
            ],
          ),
        );
      },
    );
  }
}

/// Moves focus to [node] once [child] is first built: the search field
/// takes focus from the trigger when the popover opens.
class _FocusOnMount extends StatefulWidget {
  const new({required this.node, required this.child});

  final FocusNode node;
  final Widget child;

  @override
  State<_FocusOnMount> createState() => _FocusOnMountState();
}

class _FocusOnMountState extends State<_FocusOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.node.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
