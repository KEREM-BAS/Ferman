import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/anchored_layout.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// One entry of a [Menu] (the design-system `MenuItem`): an item, a
/// separator ([MenuItem.divider]) or a heading ([MenuItem.section]).
@immutable
class MenuItem {
  /// Creates an item shown as [label].
  const new({
    required this.label,
    this.id,
    this.icon,
    this.shortcut,
    this.danger = false,
    this.disabled = false,
    this.disabledReason,
    this.checked,
    this.submenu,
    this.flipRtl,
    this.separator = false,
    this.heading,
  });

  /// A separator line (`separator: true`).
  const new divider()
    : label = '',
      id = null,
      icon = null,
      shortcut = null,
      danger = false,
      disabled = false,
      disabledReason = null,
      checked = null,
      submenu = null,
      flipRtl = null,
      separator = true,
      heading = null;

  /// A section heading showing [text] (`heading`).
  const new section(String text)
    : label = '',
      id = null,
      icon = null,
      shortcut = null,
      danger = false,
      disabled = false,
      disabledReason = null,
      checked = null,
      submenu = null,
      flipRtl = null,
      separator = false,
      heading = text;

  /// An identifier for the owner; the bundle falls back to [label].
  final String? id;

  /// The item's text.
  final String label;

  /// The leading icon; null shows none.
  final IconName? icon;

  /// The shortcut key caps, already resolved for the platform; null shows
  /// none.
  final List<String>? shortcut;

  /// Whether the item is destructive (danger colour).
  final bool danger;

  /// Whether the item cannot be activated.
  final bool disabled;

  /// Why the item cannot be activated (G10): its tooltip and semantics
  /// hint while [disabled]. Such an item stays reachable with the arrow
  /// keys; plain disabled items are skipped.
  final String? disabledReason;

  /// Whether the item is checked; null for an item that is not a checkbox.
  final bool? checked;

  /// The items of a submenu opened from this item; null for none.
  final List<MenuItem>? submenu;

  /// Whether the icon mirrors in right to left; null follows the icon.
  final bool? flipRtl;

  /// Whether this entry is a separator line.
  final bool separator;

  /// The text of a section heading; null for an item.
  final String? heading;

  /// Whether this entry is an item (not a separator or heading).
  bool get isItem => !separator && heading == null;

  @override
  String toString() =>
      separator ? 'MenuItem.divider()' : 'MenuItem(${heading ?? label})';
}

/// A popup list of items with icons, shortcuts, check marks, separators,
/// headings and submenus, the design-system `Menu` component
/// (`components/overlays/Menu.jsx`, `.fm-menu`). Never `PopupMenuButton`
/// (ADR 0011).
///
/// The menu is the surface itself: at least 208 px wide, 4 px of padding,
/// the raised colour, medium corners and the popover shadow, fading in
/// over `--dur-fast`. It is positioned by its host: inside a `Popover`
/// with `surface: false` under a trigger.
///
/// Items are 28 px rows (`.fm-menu__item`): a check column when any item
/// is checkable, the 16 px icon in the secondary icon colour, the label,
/// the shortcut as plain key caps and, for a submenu, a `chevron-right`
/// that mirrors in right to left. The check mark takes the row's icon
/// colour (`.fm-menu__item svg` wins over `.fm-menu__check`). The pointer
/// and focus tint a row with the strong selection colour (menus use the
/// tint, not a ring). Danger items take the danger colour; disabled items
/// the disabled colours and the default arrow cursor
/// (`.fm-menu__item:disabled { cursor: default }`).
/// Separators run edge to edge; headings are label type in the tertiary
/// colour.
///
/// **Keyboard.** ArrowDown and ArrowUp move between items, wrapping, past
/// plain disabled items but stopping on items disabled with a reason;
/// Home and End go to the first and last; Enter and Space activate;
/// Escape calls [onClose]. The items are not Tab stops (the menu role):
/// Tab and Shift+Tab call [onClose] too, from a submenu as well, so the
/// host closes the whole menu and returns focus to its trigger, and the
/// menu never stays open while focus moves on (the WAI-ARIA menu pattern).
/// ArrowRight (ArrowLeft in right to left) opens a submenu, as does
/// hovering its item; ArrowLeft (ArrowRight), Escape or choosing an item
/// close it. With [autofocus] the first item takes focus when the menu
/// appears.
///
/// Activating an item calls [onSelected] with it (items of submenus too).
///
/// For screen readers the menu is a menu named by [semanticLabel]; items
/// are menu items, or checkbox menu items when [MenuItem.checked] is set.
class Menu extends StatefulWidget {
  /// Creates a menu of [items].
  const new({
    super.key,
    this.items = const [],
    this.onSelected,
    this.onClose,
    this.semanticLabel,
    this.autofocus = false,
  });

  /// `.fm-menu` `min-width`.
  static const double minWidth = 208;

  /// `.fm-menu__item` `height`.
  static const double itemHeight = 28;

  /// The entries, in order.
  final List<MenuItem> items;

  /// Called with the item the user activates.
  final ValueChanged<MenuItem>? onSelected;

  /// Called on Escape, Tab and Shift+Tab.
  final VoidCallback? onClose;

  /// The accessible name of the menu (the DS `label`).
  final String? semanticLabel;

  /// Whether the first item takes focus when the menu appears.
  final bool autofocus;

  @override
  State<Menu> createState() => _MenuState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<MenuItem>('items', items))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null))
      ..add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'));
  }
}

class _MenuState extends State<Menu> {
  static const SingleActivator _tab = SingleActivator(LogicalKeyboardKey.tab);
  static const SingleActivator _shiftTab = SingleActivator(
    LogicalKeyboardKey.tab,
    shift: true,
  );

  final Map<int, FocusNode> _nodes = {};
  int? _submenu;

  FocusNode _nodeAt(int index) => _nodes[index] ??= FocusNode(
    debugLabel: 'Menu item $index',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final first = _step(-1, 1);
        if (first >= 0) _nodeAt(first).requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Whether focus can rest on the entry at [index]: items, enabled or
  /// disabled with a reason.
  bool _reachable(int index) {
    final item = widget.items[index];
    return item.isItem && (!item.disabled || item.disabledReason != null);
  }

  /// The next reachable index after [from] in [direction], wrapping; -1
  /// when there is none.
  int _step(int from, int direction) {
    final count = widget.items.length;
    for (var i = 1; i <= count; i++) {
      final index = ((from + direction * i) % count + count) % count;
      if (_reachable(index)) return index;
    }
    return -1;
  }

  int get _focused {
    for (final MapEntry(:key, :value) in _nodes.entries) {
      if (value.hasPrimaryFocus) return key;
    }
    return -1;
  }

  void _focus(int index) {
    if (index >= 0) _nodeAt(index).requestFocus();
  }

  void _openSubmenu(int index) {
    if (_submenu != index) setState(() => _submenu = index);
  }

  void _closeSubmenu({bool refocus = true}) {
    final index = _submenu;
    if (index == null) return;
    setState(() => _submenu = null);
    if (refocus) _focus(index);
  }

  void _activate(int index) {
    final item = widget.items[index];
    if (item.disabled) return;
    if (item.submenu != null) {
      _openSubmenu(index);
      return;
    }
    widget.onSelected?.call(item);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final current = _focused;
    if (key == LogicalKeyboardKey.arrowDown) {
      _focus(_step(current, 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _focus(_step(current < 0 ? 0 : current, -1));
    } else if (key == LogicalKeyboardKey.home) {
      _focus(_step(-1, 1));
    } else if (key == LogicalKeyboardKey.end) {
      _focus(_step(widget.items.length, -1));
    } else if (key ==
            (rtl
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight) &&
        current >= 0 &&
        widget.items[current].submenu != null &&
        !widget.items[current].disabled) {
      _openSubmenu(current);
    } else if (key == LogicalKeyboardKey.escape && widget.onClose != null) {
      widget.onClose?.call();
    } else if (_tab.accepts(event, HardwareKeyboard.instance) ||
        _shiftTab.accepts(event, HardwareKeyboard.instance)) {
      // A submenu lets Tab through to the menu it opened from, which
      // closes the whole menu.
      if (_SubmenuScope.within(context) || widget.onClose == null) {
        return KeyEventResult.ignored;
      }
      widget.onClose?.call();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _entry(BuildContext context, int index, {required bool checkColumn}) {
    final theme = context.ferman;
    final item = widget.items[index];
    final inset = EdgeInsetsDirectional.symmetric(
      horizontal: theme.space.space1,
    );
    if (item.separator) {
      return Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: theme.space.space1),
        child: Container(
          height: theme.border.borderWidth,
          color: theme.colors.borderSubtle,
        ),
      );
    }
    final heading = item.heading;
    if (heading != null) {
      final style = theme.typography.label;
      return Padding(
        padding: inset,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            theme.space.space2,
            theme.space.space1_5,
            theme.space.space2,
            theme.space.space1,
          ),
          child: Semantics(
            header: true,
            child: Text(
              heading,
              style: style.copyWith(
                color: theme.colors.textTertiary,
                letterSpacing: theme.typeScale.trackingLabel * style.fontSize!,
              ),
            ),
          ),
        ),
      );
    }
    Widget row = _MenuRow(
      item: item,
      node: _nodeAt(index),
      checkColumn: checkColumn,
      submenuOpen: _submenu == index,
      onPressed: () => _activate(index),
      onHover: () {
        if (item.submenu != null && !item.disabled) {
          _openSubmenu(index);
        } else if (_submenu != null) {
          _closeSubmenu(refocus: false);
        }
      },
    );
    final submenu = item.submenu;
    if (submenu != null) {
      row = _SubmenuAnchor(
        open: _submenu == index,
        items: submenu,
        onSelected: (chosen) {
          _closeSubmenu(refocus: false);
          widget.onSelected?.call(chosen);
        },
        onClose: _closeSubmenu,
        child: row,
      );
    }
    return Padding(padding: inset, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final checkColumn = widget.items.any((item) => item.checked != null);
    final hasItems = widget.items.any((item) => item.isItem);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motion.durFast,
      curve: theme.motion.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        role: hasItems ? SemanticsRole.menu : null,
        label: widget.semanticLabel,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: Menu.minWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surfaceRaised,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
                boxShadow: theme.elevation.shadowPopover,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: theme.space.space1,
                ),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        _entry(context, i, checkColumn: checkColumn),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One item row (`.fm-menu__item`).
class _MenuRow extends StatelessWidget {
  const new({
    required this.item,
    required this.node,
    required this.checkColumn,
    required this.submenuOpen,
    required this.onPressed,
    required this.onHover,
  });

  final MenuItem item;
  final FocusNode node;
  final bool checkColumn;
  final bool submenuOpen;
  final VoidCallback onPressed;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final disabled = item.disabled;
    final icon = item.icon;
    final shortcut = item.shortcut;
    final checked = item.checked;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: FermanInteractive(
        onPressed: onPressed,
        disabled: disabled,
        disabledReason: item.disabledReason,
        focusNode: node,
        isButton: false,
        tooltipSide: TooltipSide.right,
        semanticsRole: checked != null
            ? SemanticsRole.menuItemCheckbox
            : SemanticsRole.menuItem,
        builder: (context, states, _) {
          final tinted =
              !disabled &&
              (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  node.hasFocus ||
                  submenuOpen);
          final reasonFocused = disabled && node.hasFocus;
          final Color text;
          final Color iconColor;
          if (disabled) {
            text = colors.textDisabled;
            iconColor = colors.iconDisabled;
          } else if (item.danger) {
            text = colors.danger;
            iconColor = colors.danger;
          } else {
            text = colors.textPrimary;
            iconColor = colors.iconSecondary;
          }
          // `.fm-menu__item:disabled { cursor: default }`: the innermost
          // cursor wins over the forbidden one FermanInteractive sets.
          return MouseRegion(
            cursor: disabled ? SystemMouseCursors.basic : MouseCursor.defer,
            child: Semantics(
              checked: checked,
              child: Container(
                height: Menu.itemHeight,
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space2,
                ),
                decoration: BoxDecoration(
                  color: tinted || reasonFocused
                      ? colors.surfaceSelectedStrong
                      : null,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusSm),
                  ),
                ),
                child: Row(
                  spacing: theme.space.space2,
                  children: [
                    if (checkColumn)
                      SizedBox(
                        width: theme.density.iconSm,
                        child: checked ?? false
                            ? Icon(
                                IconName.check,
                                size: theme.density.iconSm,
                                strokeWidth: 2,
                                // `.fm-menu__item svg` (0,1,1) colours the
                                // check's own svg, over the span's accent
                                // (G78).
                                color: iconColor,
                              )
                            : null,
                      ),
                    if (icon != null)
                      // The default 16 px (`Icon size={16}`) at every
                      // density: the rows keep their 28 px height.
                      Icon(icon, color: iconColor, flipRtl: item.flipRtl),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(color: text),
                      ),
                    ),
                    if (shortcut != null)
                      ExcludeSemantics(
                        child: Kbd(shortcut, tone: KbdTone.plain),
                      ),
                    if (item.submenu != null)
                      Icon(
                        IconName.chevronRight,
                        size: theme.density.iconSm,
                        color: iconColor,
                        flipRtl: true,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Opens a submenu beside its item while [open].
class _SubmenuAnchor extends StatefulWidget {
  const new({
    required this.open,
    required this.items,
    required this.onSelected,
    required this.onClose,
    required this.child,
  });

  final bool open;
  final List<MenuItem> items;
  final ValueChanged<MenuItem> onSelected;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_SubmenuAnchor> createState() => _SubmenuAnchorState();
}

class _SubmenuAnchorState extends State<_SubmenuAnchor> {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'Submenu',
  );

  @override
  void initState() {
    super.initState();
    if (widget.open) _portal.show();
  }

  @override
  void didUpdateWidget(_SubmenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.open) {
          _portal.show();
        } else {
          _portal.hide();
        }
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final back = rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    if (event.logicalKey == back) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final group = Popover.groupOf(context);
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        Widget menu = Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: _SubmenuScope(
            child: Menu(
              items: widget.items,
              onSelected: widget.onSelected,
              onClose: widget.onClose,
              autofocus: true,
            ),
          ),
        );
        if (group != null) {
          menu = TapRegion(
            groupId: group,
            behavior: HitTestBehavior.opaque,
            child: menu,
          );
        }
        return CustomSingleChildLayout(
          delegate: FermanAnchoredLayout(
            anchor: FermanAnchoredLayout.anchorRect(info),
            side: AnchorSide.right.resolve(direction),
            alignment: AnchorAlignment.leading,
          ),
          child: menu,
        );
      },
      child: widget.child,
    );
  }
}

/// Marks a [Menu] opened as a submenu, which leaves Tab to the menu it
/// opened from.
class _SubmenuScope extends InheritedWidget {
  const new({required super.child});

  /// Whether [context] is inside a submenu.
  static bool within(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SubmenuScope>() != null;

  @override
  bool updateShouldNotify(_SubmenuScope oldWidget) => false;
}
