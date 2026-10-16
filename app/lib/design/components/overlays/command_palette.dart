import 'dart:async';

import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/components/foundation/modal_scope.dart';
import 'package:ferman/design/components/overlays/scrim.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A titled group of commands in a [CommandPalette] (the spec's
/// `CommandGroup`).
typedef CommandGroup = ({String label, List<CommandItem> items});

/// A key-cap hint in the palette's footer ("↑ ↓ Move"): the caps and the
/// label after them.
typedef CommandFooterHint = ({List<String> keys, String label});

/// One command of a [CommandPalette] (the design-system `CommandItem`).
@immutable
class CommandItem {
  /// Creates a command [id] shown as [label].
  const new({
    required this.id,
    required this.label,
    this.icon = IconName.command,
    this.hint,
    this.shortcut,
    this.keywords,
    this.disabledReason,
  });

  /// The command's identifier.
  final String id;

  /// The command's name.
  final String label;

  /// The leading icon.
  final IconName icon;

  /// A short note after the label ("Page 4"); null shows none.
  final String? hint;

  /// The shortcut key caps, already resolved for the platform; null shows
  /// none.
  final List<String>? shortcut;

  /// More words the search matches; null for none.
  final String? keywords;

  /// Why the command cannot run (G10): it shows the disabled look, its
  /// tooltip and semantics hint, and Enter does nothing; null for an
  /// available command.
  final String? disabledReason;

  @override
  String toString() => 'CommandItem($id)';
}

/// A search-first list of commands in groups, with highlighted matches,
/// hints and shortcuts, over a top scrim, the design-system
/// `CommandPalette` component (`components/overlays/CommandPalette.jsx`,
/// `.fm-palette`).
///
/// The palette is `--palette-w` (600 px) wide with large corners and the
/// dialog shadow, rising in over `--dur-base`. Its 48 px input row holds a
/// `search` glyph, the 16 px search field ([placeholder]) and [escapeKeys]
/// as key caps; the list below (at most 344 px, scrolling) shows the
/// [groups] whose commands match the query, each under its label. A
/// command row (34 px) shows its icon, its label with the matched part in
/// semibold, its hint and its shortcut; the active row takes the strong
/// selection tint and an accent icon. With no match the list shows
/// [emptyText]. The footer lists [footerHints] ("↑ ↓ Move", "↵ Run",
/// "Esc Close").
///
/// **Modal.** Unless [inline], the palette shows while [open] in the root
/// [Overlay] (through an [OverlayPortal] at
/// [OverlayChildLocation.rootOverlay]), 14 % from the
/// top over the lighter [Scrim], which covers the whole window, the title
/// bar included; [ModalScope] counts it while it shows. Screen readers see
/// only the palette, and the search field takes focus. A pointer down on
/// the scrim calls [onClose]. [inline] draws it in place (boards, the
/// gallery).
///
/// **Keyboard.** Focus stays in the search field, which shows no ring.
/// ArrowDown and ArrowUp move the active command (stopping at the ends;
/// nothing with no match), Enter runs it ([onSelected]; nothing for a
/// command disabled with a reason), Escape calls [onClose]. Moving the
/// pointer over a row makes it active; a click runs it. The list scrolls
/// only to bring the active row into view, 6 px clear of the edge, as the
/// bundle does. A command disabled with a reason shows the reason as a
/// tooltip while it is the active row (G10). Flutter has no
/// `aria-activedescendant`: where the platform supports announcements,
/// moving the active command with the arrow keys announces its label and
/// its reason or hint.
///
/// **Matching.** A command matches when its label and keywords contain the
/// query, compared in lower case with the casing rules of the UI language
/// ([LocaleCasing]; the bundle always uses Turkish rules, COMPONENTS.md
/// decision 18).
///
/// The query is [query] when given (with [onQueryChanged] reporting
/// edits), else kept in the field.
///
/// For screen readers the palette is a dialog named by [semanticLabel];
/// the field is a text field named by [placeholder] (the bundle's input
/// takes its name from the placeholder); commands are buttons, the active
/// one selected.
class CommandPalette extends StatefulWidget {
  /// Creates a palette over [groups].
  const new({
    super.key,
    this.open = true,
    this.inline = false,
    this.groups = const [],
    this.query,
    this.onQueryChanged,
    this.onSelected,
    this.onClose,
    this.placeholder = '',
    this.emptyText,
    this.semanticLabel,
    this.escapeKeys,
    this.footerHints = const [],
  });

  /// `.fm-palette__input` `height`.
  static const double inputHeight = 48;

  /// `.fm-palette__item` `height`.
  static const double itemHeight = 34;

  /// `.fm-palette__list` `max-height`.
  static const double listMaxHeight = 344;

  /// `.fm-palette__foot` `height`.
  static const double footHeight = 34;

  /// The input row's `search` glyph size (`Icon size={18}`).
  static const double searchIconSize = 18;

  /// `.fm-palette__empty` vertical padding.
  static const double emptyPadding = 28;

  /// `fm-rise-in`: how far the palette rises while it fades in.
  static const double riseDistance = 4;

  /// How far clear of the list's edge a row scrolled into view lands (the
  /// bundle's `scrollTop = top - 6`).
  static const double revealMargin = 6;

  /// Whether the palette is shown.
  final bool open;

  /// Whether to draw the palette in place, without the scrim.
  final bool inline;

  /// The commands, in groups.
  final List<CommandGroup> groups;

  /// The query; null keeps it in the field.
  final String? query;

  /// Called with the query after each edit.
  final ValueChanged<String>? onQueryChanged;

  /// Called with the command the user runs.
  final ValueChanged<CommandItem>? onSelected;

  /// Called on Escape and on a pointer down on the scrim.
  final VoidCallback? onClose;

  /// The search field's placeholder ("Search commands, pages and text").
  final String placeholder;

  /// The text shown when no command matches ("No commands match “q”. Press
  /// Enter to search the document instead."); null shows none.
  final String? emptyText;

  /// The accessible name of the palette ("Command palette"). Not a
  /// design-system prop.
  final String? semanticLabel;

  /// The key caps at the end of the input row (["Esc"]); null shows none.
  /// Not a design-system prop.
  final List<String>? escapeKeys;

  /// The key hints of the footer; empty hides the footer. Not a
  /// design-system prop.
  final List<CommandFooterHint> footerHints;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('open', value: open, ifFalse: 'closed'))
      ..add(FlagProperty('inline', value: inline, ifTrue: 'inline'))
      ..add(IntProperty('groups', groups.length))
      ..add(StringProperty('query', query, defaultValue: null))
      ..add(StringProperty('placeholder', placeholder, defaultValue: ''))
      ..add(StringProperty('emptyText', emptyText, defaultValue: null));
  }
}

class _CommandPaletteState extends State<CommandPalette> {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'CommandPalette',
  );
  late final TextEditingController _field = TextEditingController(
    text: widget.query ?? '',
  );
  final FocusNode _fieldNode = FocusNode(debugLabel: 'CommandPalette field');
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'CommandPalette');
  final ScrollController _scroll = ScrollController();

  /// One key per visible row, by its place in the list (a command may sit
  /// in two groups).
  final List<GlobalKey> _rowKeys = [];
  int _active = 0;
  FocusNode? _restore;
  ModalHandle? _modalHandle;

  bool get _modal => widget.open && !widget.inline;

  String get _query => widget.query ?? _field.text;

  @override
  void initState() {
    super.initState();
    if (_modal) {
      _portal.show();
      _focusField();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _portal.isShowing) _openModal();
      });
    }
  }

  @override
  void didUpdateWidget(CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.query;
    if (query != null && query != _field.text) {
      _field.text = query;
      _active = 0;
    }
    final wasModal = oldWidget.open && !oldWidget.inline;
    if (wasModal != _modal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_modal && !_portal.isShowing) {
          _portal.show();
          _openModal();
          _focusField();
        } else if (!_modal && _portal.isShowing) {
          _portal.hide();
          _closeModal();
          _restoreFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _closeModal();
    _restoreFocus();
    _field.dispose();
    _fieldNode.dispose();
    _scope.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openModal() {
    _modalHandle ??= ModalScope.open(debugLabel: 'CommandPalette');
  }

  void _closeModal() {
    _modalHandle?.close();
    _modalHandle = null;
  }

  void _focusField() {
    _restore = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldNode.requestFocus();
    });
  }

  void _restoreFocus() {
    final restore = _restore;
    _restore = null;
    if (restore != null && restore.context != null && restore.canRequestFocus) {
      restore.requestFocus();
    }
  }

  List<CommandGroup> _filtered(LocaleCasing casing) {
    final query = casing.lower(_query);
    return [
      for (final group in widget.groups)
        if (_matching(group.items, query, casing) case final items
            when items.isNotEmpty)
          (label: group.label, items: items),
    ];
  }

  static List<CommandItem> _matching(
    List<CommandItem> items,
    String query,
    LocaleCasing casing,
  ) => [
    for (final item in items)
      if (query.isEmpty ||
          casing.lower('${item.label} ${item.keywords ?? ''}').contains(query))
        item,
  ];

  void _run(CommandItem item) {
    if (item.disabledReason != null) return;
    widget.onSelected?.call(item);
  }

  /// Makes the row at [index] the active one; false when it already was or
  /// there is no such row.
  bool _setActive(int index, List<CommandItem> flat) {
    if (index == _active || index < 0 || index >= flat.length) return false;
    setState(() => _active = index);
    final key = index < _rowKeys.length ? _rowKeys[index] : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = key?.currentContext;
      if (mounted && row != null && row.mounted) _reveal(row);
    });
    return true;
  }

  /// Scrolls the list just enough to show [row], 6 px clear of the edge it
  /// crossed, and not at all when it is in view (the bundle's
  /// `if (top < lt) scrollTop = top - 6; else if (bottom > lt + lh) …`).
  /// Only the list scrolls, never a scrollable around an inline palette.
  void _reveal(BuildContext row) {
    if (!_scroll.hasClients) return;
    final box = row.findRenderObject();
    if (box == null || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scroll.position;
    final atTop = viewport.getOffsetToReveal(box, 0).offset;
    final atBottom = viewport.getOffsetToReveal(box, 1).offset;
    final double target;
    if (atTop < position.pixels) {
      target = atTop - CommandPalette.revealMargin;
    } else if (atBottom > position.pixels) {
      target = atBottom + CommandPalette.revealMargin;
    } else {
      return;
    }
    position.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  /// Tells screen readers which command the arrow keys made active (the
  /// bundle's `aria-activedescendant`), where the platform takes
  /// announcements.
  void _announceActive(CommandItem item) {
    final view = View.maybeOf(context);
    if (view == null ||
        !(MediaQuery.maybeSupportsAnnounceOf(context) ?? false)) {
      return;
    }
    final extra = item.disabledReason ?? item.hint;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        extra == null ? item.label : '${item.label}, $extra',
        Directionality.of(context),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final flat = [
      for (final group in _filtered(LocaleCasing.of(context))) ...group.items,
    ];
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      // With no match there is nothing to move, but the keys stay with the
      // palette.
      if (flat.isNotEmpty) {
        final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        final index = (_active + step).clamp(0, flat.length - 1);
        if (_setActive(index, flat)) _announceActive(flat[index]);
      }
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_active < flat.length) _run(flat[_active]);
    } else if (key == LogicalKeyboardKey.escape) {
      widget.onClose?.call();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _label(BuildContext context, String label, LocaleCasing casing) {
    final theme = context.ferman;
    final style = theme.typography.body;
    final query = _query;
    final lowered = casing.lower(label);
    final at = query.isEmpty ? -1 : lowered.indexOf(casing.lower(query));
    // Highlight only when lower-casing kept the length, so the indices
    // still point into the label.
    if (at < 0 || lowered.length != label.length) {
      return Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final end = at + casing.lower(query).length;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: label.substring(0, at)),
          TextSpan(
            text: label.substring(at, end),
            style: TextStyle(
              fontWeight: theme.typeScale.weightSemibold,
              color: theme.colors.textPrimary,
            ),
          ),
          TextSpan(text: label.substring(end)),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _palette(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final casing = LocaleCasing.of(context);
    final groups = _filtered(casing);
    final flat = [for (final group in groups) ...group.items];
    if (_active >= flat.length) _active = flat.isEmpty ? 0 : flat.length - 1;
    while (_rowKeys.length < flat.length) {
      _rowKeys.add(GlobalKey(debugLabel: 'Command row ${_rowKeys.length}'));
    }
    if (_rowKeys.length > flat.length) _rowKeys.length = flat.length;
    final escape = widget.escapeKeys;
    final empty = widget.emptyText;
    final fieldStyle = theme.typography.dialogTitle.copyWith(
      fontWeight: theme.typeScale.weightRegular,
      color: colors.textPrimary,
    );
    var index = -1;
    final list = <Widget>[];
    for (final group in groups) {
      final style = theme.typography.label;
      list.add(
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            theme.space.space2_5,
            theme.space.space2_5,
            theme.space.space2_5,
            theme.space.space1,
          ),
          child: Semantics(
            header: true,
            child: Text(
              group.label,
              style: style.copyWith(
                color: colors.textTertiary,
                letterSpacing: theme.typeScale.trackingLabel * style.fontSize!,
              ),
            ),
          ),
        ),
      );
      for (final item in group.items) {
        index += 1;
        final at = index;
        list.add(
          _CommandRow(
            key: _rowKeys[at],
            item: item,
            active: at == _active,
            label: _label(context, item.label, casing),
            onHover: () => _setActive(at, flat),
            onPressed: () => _run(item),
          ),
        );
      }
    }
    final border = BorderSide(
      color: colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final palette = Container(
      width: theme.size.paletteW,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusLg)),
        boxShadow: theme.elevation.shadowDialog,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: CommandPalette.inputHeight,
            padding: EdgeInsetsDirectional.fromSTEB(
              theme.space.space4,
              0,
              theme.space.space3 + theme.space.space0_5,
              0,
            ),
            decoration: BoxDecoration(border: Border(bottom: border)),
            child: Row(
              spacing: theme.space.space2_5,
              children: [
                Icon(
                  IconName.search,
                  size: CommandPalette.searchIconSize,
                  color: colors.iconSecondary,
                ),
                Expanded(
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    includeSemantics: false,
                    onKeyEvent: _onKey,
                    // FieldInput leaves its name to its owner; the bundle's
                    // input is named by its placeholder.
                    child: MergeSemantics(
                      child: Semantics(
                        label: widget.placeholder.isEmpty
                            ? null
                            : widget.placeholder,
                        child: FieldInput(
                          controller: _field,
                          focusNode: _fieldNode,
                          style: fieldStyle,
                          placeholder: widget.placeholder.isEmpty
                              ? null
                              : widget.placeholder,
                          onChanged: (text) {
                            setState(() => _active = 0);
                            widget.onQueryChanged?.call(text);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (escape != null) Kbd(escape),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: CommandPalette.listMaxHeight,
            ),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsetsDirectional.fromSTEB(
                theme.space.space1_5,
                theme.space.space1,
                theme.space.space1_5,
                theme.space.space1_5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...list,
                  if (flat.isEmpty && empty != null)
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: theme.space.space4,
                        vertical: CommandPalette.emptyPadding,
                      ),
                      child: Text(
                        empty,
                        textAlign: TextAlign.center,
                        style: theme.typography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.footerHints.isNotEmpty)
            Container(
              height: CommandPalette.footHeight,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space3 + theme.space.space0_5,
              ),
              decoration: BoxDecoration(
                color: colors.surfacePanel,
                border: Border(top: border),
              ),
              child: Row(
                spacing: theme.space.space4,
                children: [
                  for (final hint in widget.footerHints)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: theme.space.space1_5,
                      children: [
                        Kbd(hint.keys),
                        Text(
                          hint.label,
                          style: theme.typography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motion.durBase,
      curve: theme.motion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, CommandPalette.riseDistance * (1 - t)),
          child: child,
        ),
      ),
      child: Semantics(
        container: true,
        scopesRoute: _modal,
        namesRoute: widget.semanticLabel != null,
        explicitChildNodes: true,
        role: SemanticsRole.dialog,
        label: widget.semanticLabel,
        child: palette,
      ),
    );
  }

  Widget _modalLayer(BuildContext context) => PositionedDirectional(
    start: 0,
    end: 0,
    top: 0,
    bottom: 0,
    child: BlockSemantics(
      child: Scrim(
        top: true,
        onDismiss: widget.onClose,
        child: FocusScope(node: _scope, child: _palette(context)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.inline) {
      return widget.open ? _palette(context) : const SizedBox();
    }
    // The root overlay, so the scrim covers the title bar and every
    // nested navigator's screen.
    return OverlayPortal(
      overlayLocation: OverlayChildLocation.rootOverlay,
      controller: _portal,
      overlayChildBuilder: _modalLayer,
      child: const SizedBox.shrink(),
    );
  }
}

/// One command row (`.fm-palette__item`).
class _CommandRow extends StatelessWidget {
  const new({
    required this.item,
    required this.active,
    required this.label,
    required this.onHover,
    required this.onPressed,
    super.key,
  });

  final CommandItem item;
  final bool active;
  final Widget label;
  final VoidCallback onHover;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final reason = item.disabledReason;
    final disabled = reason != null;
    final hint = item.hint;
    final shortcut = item.shortcut;
    final Color iconColor;
    if (disabled) {
      iconColor = colors.iconDisabled;
    } else if (active) {
      iconColor = colors.textAccent;
    } else {
      iconColor = colors.iconSecondary;
    }
    Widget row = MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onHover: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onPressed,
        child: Container(
          height: CommandPalette.itemHeight,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space2_5,
          ),
          decoration: BoxDecoration(
            color: active ? colors.surfaceSelectedStrong : null,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusSm),
            ),
          ),
          child: Row(
            spacing: theme.space.space2_5,
            children: [
              // The default 16 px (`Icon size={16}`) at every density: the
              // rows keep their 34 px height.
              Icon(item.icon, color: iconColor),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: disabled ? colors.textDisabled : colors.textPrimary,
                  ),
                  child: label,
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  softWrap: false,
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              if (shortcut != null) Kbd(shortcut, tone: KbdTone.plain),
            ],
          ),
        ),
      ),
    );
    row = Semantics(
      container: true,
      button: true,
      selected: active,
      enabled: !disabled,
      label: item.label,
      hint: reason ?? hint,
      onTap: disabled ? null : onPressed,
      child: ExcludeSemantics(child: row),
    );
    if (reason != null) {
      // Also while the row is the active one, so keyboard users, whose
      // focus stays in the field, can read the reason (G10).
      row = Tooltip(
        message: reason,
        side: TooltipSide.right,
        hovered: active,
        excludeFromSemantics: true,
        child: row,
      );
    }
    return row;
  }
}
