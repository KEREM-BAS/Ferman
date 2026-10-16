import 'dart:math' as math;

import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/forms/select.dart';
import 'package:ferman/design/components/forms/switch.dart';
import 'package:ferman/design/components/navigation/label_collapse.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/components/navigation/tool_button.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// How a [Toolbar] is drawn (`.fm-toolbar--bar`, `.fm-toolbar--floating`).
enum ToolbarVariant {
  /// The tool row under the mode bar: full width, `--toolbar-h` tall, on
  /// the panel surface with a bottom border.
  bar,

  /// A raised pill floating over the document (`--shadow-popover`).
  floating,
}

/// When an item of a [Toolbar] bar leaves the row that runs out of room
/// (G21).
enum ToolbarOverflow {
  /// It moves into the overflow menu, the last such item first. The
  /// default for an item before a [ToolbarSpacer] that has a menu entry.
  auto,

  /// It moves into the menu only after every [auto] item has. The default
  /// for an item after a [ToolbarSpacer]: the row's end actions, such as
  /// "Apply redactions", stay in the row longest.
  late,

  /// It is never listed: it hides when the row runs out of room, before
  /// any label does. The default for an item without a menu entry (the
  /// Organize row's hint).
  hide,
}

/// A row of tools, the design-system `Toolbar` component
/// (`components/navigation/navigation.css`, `.fm-toolbar`; `Toolbar.jsx`).
///
/// [children] are laid out in a row 2 px apart, in order: tool buttons,
/// icon buttons, selects, segmented controls, [ToolbarSeparator]s between
/// groups, a [ToolbarSpacer] to push the rest to the end, and
/// [ToolbarGroup]s. Pass them directly, not wrapped (except in a
/// [ToolbarItem]), so the toolbar can tell what each one is.
///
/// **Narrow windows** (G21; the 12 Localization rule). When a bar runs out
/// of room it frees space in this order, one item at a time, until the row
/// fits:
///
/// 1. items without a menu entry ([ToolbarOverflow.hide], a hint) hide,
///    from the end;
/// 2. the labels of inline [ToolButton]s hide behind their icons, from the
///    end; the tooltip then gives the label;
/// 3. items move into the overflow menu, from the end
///    ([ToolbarOverflow.auto]), then the ones after the spacer
///    ([ToolbarOverflow.late]).
///
/// The overflow button (the `ellipsis` icon, named [overflowLabel], "More
/// tools") takes the place of the first item that moved, so it sits at the
/// end of the tools still shown, mirrored in right to left. Its menu, the
/// design-system [Menu] in a [Popover], lists exactly the items that moved,
/// in row order, with a separator where the row had one: a [ToolButton],
/// an [IconButton] or a [Switch] as an item with its label, icon and
/// shortcut, checked when the tool is on (toggles show their state), and
/// disabled with its reason (G10); other items through
/// [ToolbarItem.menuItem]. Choosing an entry closes the menu, gives focus
/// back to the overflow button and does what the item does. Separators
/// hide when nothing shown is left on one of their sides. Everything is
/// driven by the width the row is given, never by the platform, and the
/// items stay in the tree, so their state and focus survive a resize: a
/// focused tool that moves into the menu hands focus to the overflow
/// button, and the button hands it back to that tool when it returns (or,
/// when the button leaves the row and that tool cannot take focus, to the
/// first tool that returned); focus never leaves an open menu. An item
/// that moves into the menu closes the popovers it opened (a select's
/// list), through `PopoverAnchorVisibility`.
/// Without an [overflowLabel] nothing moves into a menu; what still does
/// not fit is clipped. A floating toolbar is sized by its content and
/// never collapses.
///
/// **Keyboard** (`Toolbar.jsx`): every item stays a Tab stop, and
/// ArrowLeft and ArrowRight move focus to the previous and next item in the
/// visual direction (mirrored in right to left), wrapping, in the order the
/// items appear on screen. The overflow button is one of them; Enter, Space
/// and ArrowDown open its menu. They stop on enabled items and on disabled
/// items that give a reason (which stay focusable, G10), and skip plain
/// disabled ones. Inside a segmented control, tab strip or radio group only
/// its Tab stop is visited, and the group's own arrow keys win while focus
/// is in it. While focus is in a text field or a [Select], the arrows are
/// left to it (`Toolbar.jsx` skips `INPUT` and `SELECT`), so focus never
/// leaves an open select list.
///
/// **Semantics:** a container labelled [semanticLabel] that keeps its
/// items as separate nodes; items out of the row are left out. Flutter has
/// no toolbar role.
class Toolbar extends StatefulWidget {
  /// A toolbar of [children].
  const new({
    required this.semanticLabel,
    required this.children,
    super.key,
    this.variant = ToolbarVariant.bar,
    this.overflowLabel,
  });

  /// How the toolbar is drawn.
  final ToolbarVariant variant;

  /// The accessible name of the toolbar (the design's `label`), for
  /// example the localized "Comment tools".
  final String semanticLabel;

  /// The items, in order.
  final List<Widget> children;

  /// The name and tooltip of the overflow button and the name of its menu,
  /// the localized "More tools" (G21); null gives the bar no overflow
  /// menu. Not a design-system prop.
  final String? overflowLabel;

  /// `.fm-toolbar--floating` `padding: 3px`.
  static const double floatingPadding = 3;

  @override
  State<Toolbar> createState() => _ToolbarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<ToolbarVariant>(
          'variant',
          variant,
          defaultValue: ToolbarVariant.bar,
        ),
      )
      ..add(StringProperty('semanticLabel', semanticLabel))
      ..add(IntProperty('children', children.length))
      ..add(StringProperty('overflowLabel', overflowLabel, defaultValue: null));
  }
}

/// An item of a [Toolbar] and what it becomes in a row that runs out of
/// room (G21): its entry in the overflow menu, and when it moves there.
///
/// A [ToolButton], an [IconButton] or a [Switch] needs no wrapper: the
/// toolbar takes its entry from it. Wrap any other item that should be
/// listed, such as a [Select] (a submenu of its options) or a `Button`
/// (the row's labelled actions), with its [menuItem]. An item the
/// toolbar cannot list hides when room runs out.
///
/// It builds [child] unchanged. Not a design-system component.
class ToolbarItem extends StatelessWidget {
  /// [child] with its overflow entry [menuItem].
  const new({
    required this.child,
    super.key,
    this.menuItem,
    this.onMenuSelected,
    this.overflow,
  });

  /// The item shown in the row.
  final Widget child;

  /// Its entry in the overflow menu, with a submenu for a choice of
  /// values; null takes it from [child].
  final MenuItem? menuItem;

  /// Called with the entry chosen in the overflow menu: [menuItem] itself
  /// or one of its submenu items.
  final ValueChanged<MenuItem>? onMenuSelected;

  /// When the item leaves the row; null: [ToolbarOverflow.auto] before a
  /// [ToolbarSpacer], [ToolbarOverflow.late] after it, and
  /// [ToolbarOverflow.hide] when the item has no menu entry.
  final ToolbarOverflow? overflow;

  @override
  Widget build(BuildContext context) => child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<MenuItem>('menuItem', menuItem))
      ..add(
        EnumProperty<ToolbarOverflow>('overflow', overflow, defaultValue: null),
      );
  }
}

/// An overflow-menu entry and what choosing it does.
final class _Entry {
  const new(this.item, this.onSelected);

  final MenuItem item;
  final ValueChanged<MenuItem>? onSelected;
}

/// What a child of the bar is.
enum _SlotKind { item, separator, spacer, overflowButton }

/// Which items of a bar are out of the row, by child index.
@immutable
final class _ToolbarPlan {
  const new({
    this.hidden = const {},
    this.compact = const {},
    this.overflowed = const {},
  });

  /// Nothing collapsed.
  static const _ToolbarPlan none = _ToolbarPlan();

  /// Items without a menu entry, hidden.
  final Set<int> hidden;

  /// Tools drawn with their label hidden.
  final Set<int> compact;

  /// Items in the overflow menu.
  final Set<int> overflowed;

  bool get hasOverflow => overflowed.isNotEmpty;

  /// Whether the item at [index] is in the row.
  bool shows(int index) =>
      !hidden.contains(index) && !overflowed.contains(index);

  _ToolbarPlan _with({int? hide, int? compactOne, int? overflow}) =>
      _ToolbarPlan(
        hidden: {...hidden, ?hide},
        compact: {
          for (final index in compact)
            if (index != overflow) index,
          ?compactOne,
        },
        overflowed: {...overflowed, ?overflow},
      );

  /// The plan that fits [measures] (the bar's children, without the
  /// overflow button) into [available], collapsing in the documented
  /// order; [buttonWidth] is the overflow button's width, or null when the
  /// bar has none.
  static _ToolbarPlan fit(
    List<_Measure> measures,
    double spacing,
    double? buttonWidth,
    double available,
  ) {
    var plan = none;
    bool fits() =>
        _width(measures, plan, spacing, buttonWidth ?? 0) <= available + 0.01;
    if (fits()) return plan;
    final items = [
      for (var i = 0; i < measures.length; i++)
        if (measures[i].kind == _SlotKind.item) i,
    ].reversed.toList();
    for (final i in items) {
      if (measures[i].overflow != ToolbarOverflow.hide) continue;
      plan = plan._with(hide: i);
      if (fits()) return plan;
    }
    for (final i in items) {
      final m = measures[i];
      if (!m.collapsible || !plan.shows(i) || m.compact >= m.full) continue;
      plan = plan._with(compactOne: i);
      if (fits()) return plan;
    }
    if (buttonWidth == null) return plan;
    for (final mode in [ToolbarOverflow.auto, ToolbarOverflow.late]) {
      for (final i in items) {
        if (measures[i].overflow != mode) continue;
        plan = plan._with(overflow: i);
        if (fits()) return plan;
      }
    }
    return plan;
  }

  /// The entries of the row for [plan] in logical order: child indices,
  /// and -1 for the overflow button, which takes the place of the first
  /// item that moved into it. A separator stays only with a shown item (or
  /// the button) right before it and one after it before any spacer.
  static List<int> sequence(List<_Measure> measures, _ToolbarPlan plan) {
    final first = plan.overflowed.isEmpty
        ? null
        : plan.overflowed.reduce(math.min);
    final raw = <int>[];
    for (var i = 0; i < measures.length; i++) {
      if (i == first) raw.add(-1);
      if (measures[i].kind != _SlotKind.item || plan.shows(i)) raw.add(i);
    }
    bool isTool(int entry) =>
        entry == -1 || measures[entry].kind == _SlotKind.item;
    bool toolFollows(int from) {
      for (var k = from; k < raw.length; k++) {
        final entry = raw[k];
        if (isTool(entry)) return true;
        if (measures[entry].kind == _SlotKind.spacer) return false;
      }
      return false;
    }

    final result = <int>[];
    for (var k = 0; k < raw.length; k++) {
      final entry = raw[k];
      if (entry != -1 && measures[entry].kind == _SlotKind.separator) {
        final before = result.isNotEmpty && isTool(result.last);
        if (!before || !toolFollows(k + 1)) continue;
      }
      result.add(entry);
    }
    return result;
  }

  static double _width(
    List<_Measure> measures,
    _ToolbarPlan plan,
    double spacing,
    double buttonWidth,
  ) {
    final entries = sequence(measures, plan);
    var width = spacing * math.max(0, entries.length - 1);
    for (final entry in entries) {
      if (entry == -1) {
        width += buttonWidth;
        continue;
      }
      final m = measures[entry];
      width += plan.compact.contains(entry) ? m.compact : m.full;
    }
    return width;
  }

  @override
  bool operator ==(Object other) =>
      other is _ToolbarPlan &&
      setEquals(other.hidden, hidden) &&
      setEquals(other.compact, compact) &&
      setEquals(other.overflowed, overflowed);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(hidden),
    Object.hashAllUnordered(compact),
    Object.hashAllUnordered(overflowed),
  );

  @override
  String toString() =>
      '_ToolbarPlan(hidden: $hidden, compact: $compact, '
      'overflowed: $overflowed)';
}

/// What the bar knows of a child when it plans.
typedef _Measure = ({
  _SlotKind kind,
  ToolbarOverflow overflow,
  bool collapsible,
  double full,
  double compact,
});

/// Which items are out of the row, by item id (the item's key, or its
/// index): what the widgets show. Keyed by id, so a plan laid out for one
/// list of children never lands on the wrong items of the next.
@immutable
final class _RowPlan {
  const new({
    this.hidden = const {},
    this.compact = const {},
    this.overflowed = const {},
  });

  /// [plan], laid out by index, for the items [ids] names by index.
  factory of(_ToolbarPlan plan, List<Object> ids) {
    Set<Object> map(Set<int> indexes) => {
      for (final index in indexes)
        if (index < ids.length) ids[index],
    };
    return _RowPlan(
      hidden: map(plan.hidden),
      compact: map(plan.compact),
      overflowed: map(plan.overflowed),
    );
  }

  /// Nothing collapsed.
  static const _RowPlan none = _RowPlan();

  final Set<Object> hidden;
  final Set<Object> compact;
  final Set<Object> overflowed;

  bool get hasOverflow => overflowed.isNotEmpty;

  /// Whether the item [id] is in the row.
  bool shows(Object id) => !hidden.contains(id) && !overflowed.contains(id);

  @override
  bool operator ==(Object other) =>
      other is _RowPlan &&
      setEquals(other.hidden, hidden) &&
      setEquals(other.compact, compact) &&
      setEquals(other.overflowed, overflowed);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(hidden),
    Object.hashAllUnordered(compact),
    Object.hashAllUnordered(overflowed),
  );
}

class _ToolbarState extends State<Toolbar> {
  /// The plan the widgets show: tooltips, focus and the menu follow it.
  /// The row's render object applies a new plan at once and reports it;
  /// the widgets follow after the frame.
  _RowPlan _plan = _RowPlan.none;
  _RowPlan? _pendingPlan;
  bool _syncScheduled = false;
  bool _menuOpen = false;

  /// The id of the item that handed focus to the overflow button when it
  /// moved into the menu; it gets focus back when it returns. Cleared when
  /// focus leaves the button and its menu.
  Object? _handedFrom;

  /// One node around each item, to tell where focus is and to take items
  /// out of the row out of focus traversal. Keyed like the items (their
  /// key, or their index), so a keyed item keeps its node when items are
  /// added before it.
  final Map<Object, FocusNode> _slotNodes = {};

  /// The id of each item, by index, as last built.
  List<Object> _slotIds = const [];

  /// The node around the overflow button and its menu.
  final FocusNode _overflowSlot = FocusNode(
    debugLabel: 'Toolbar overflow slot',
    canRequestFocus: false,
    skipTraversal: true,
  );

  final FocusNode _overflowNode = FocusNode(debugLabel: 'Toolbar overflow');

  @override
  void initState() {
    super.initState();
    _overflowSlot.addListener(() {
      if (!_overflowSlot.hasFocus) _handedFrom = null;
    });
  }

  FocusNode _slotNode(Object id) => _slotNodes.putIfAbsent(
    id,
    () => FocusNode(
      debugLabel: 'Toolbar item $id',
      canRequestFocus: false,
      skipTraversal: true,
    ),
  );

  /// Disposes the nodes of items that are gone, once their widgets are.
  void _dropStaleNodes() {
    final live = _slotIds.toSet();
    final stale = [
      for (final id in _slotNodes.keys)
        if (!live.contains(id)) id,
    ];
    if (stale.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final id in stale) {
        if (_slotIds.contains(id)) continue;
        _slotNodes.remove(id)?.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _slotNodes.values) {
      node.dispose();
    }
    _overflowSlot.dispose();
    _overflowNode.dispose();
    super.dispose();
  }

  /// Called by the row's render object with the plan it laid out, by the
  /// index of the children of the build that just ran ([_slotIds]).
  void _onPlan(_ToolbarPlan laidOut) {
    final plan = _RowPlan.of(laidOut, _slotIds);
    if (!_syncScheduled && plan == _plan) return;
    _pendingPlan = plan;
    if (_syncScheduled) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      _sync();
    });
  }

  /// Brings focus, tooltips and the menu in line with the laid-out plan:
  /// items out of the row leave focus traversal when the widgets rebuild,
  /// and focus follows the item it was on. Focus never leaves an open menu.
  void _sync() {
    final next = _pendingPlan;
    _pendingPlan = null;
    if (!mounted || next == null || next == _plan) return;
    final previous = _plan;
    Object? focused;
    for (final id in _slotIds) {
      if (_slotNodes[id]?.hasFocus ?? false) focused = id;
    }
    // Read before the rebuild, which can take focus off the button.
    final overflowFocused = _overflowSlot.hasFocus;
    final onButton = _overflowNode.hasPrimaryFocus;
    final handedFrom = _handedFrom;
    final toButton =
        focused != null && !next.shows(focused) && next.hasOverflow;
    if (toButton) _handedFrom = focused;
    setState(() {
      _plan = next;
      if (!next.hasOverflow) _menuOpen = false;
    });
    final back = overflowFocused && !next.hasOverflow;
    final returned =
        handedFrom != null &&
        _slotIds.contains(handedFrom) &&
        next.shows(handedFrom) &&
        (onButton || back);
    if (!toButton && !back && !returned) return;
    // Once the rebuild has made the target focusable.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (toButton) {
        _overflowNode.requestFocus();
        return;
      }
      // The item that handed focus over, or, when the button leaves the
      // row and it cannot take focus, the first item that came back.
      final candidates = [
        if (returned) handedFrom,
        if (back)
          for (final id in _slotIds)
            if (previous.overflowed.contains(id)) id,
      ];
      for (final id in candidates) {
        final targets = _slotNodes[id]?.traversalDescendants;
        if (targets != null && targets.isNotEmpty) {
          targets.first.requestFocus();
          return;
        }
      }
    });
  }

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
    _overflowNode.requestFocus();
  }

  KeyEventResult _onKey(BuildContext context, FocusNode node, KeyEvent event) {
    final step = RovingFocus.stepFor(event, Directionality.of(context));
    if (step == null) return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || focused == node) return KeyEventResult.ignored;
    // In a text field the arrows move the caret; a select keeps them too.
    final focusedContext = focused.context;
    if (focusedContext == null ||
        focusedContext.findAncestorStateOfType<EditableTextState>() != null ||
        _inSelect(focusedContext, context)) {
      return KeyEventResult.ignored;
    }
    // The items: the Tab stops that are not inside another Tab stop of the
    // toolbar (`descendants` lists a node after its own descendants).
    final stops = node.traversalDescendants.toList();
    final inToolbar = stops.toSet();
    final items = [
      for (final stop in stops)
        if (!stop.ancestors
            .takeWhile((ancestor) => ancestor != node)
            .any(inToolbar.contains))
          stop,
    ];
    // In the order on screen, not the order the focus nodes were attached
    // (a tool added later would come last).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    mergeSort<FocusNode>(
      items,
      compare: (a, b) => rtl
          ? b.rect.right.compareTo(a.rect.right)
          : a.rect.left.compareTo(b.rect.left),
    );
    final from = items.indexWhere(
      (item) => item == focused || focused.ancestors.contains(item),
    );
    if (from < 0) return KeyEventResult.ignored;
    final to = RovingFocus.target(from, items.length, step, (_) => true);
    if (to == null) return KeyEventResult.handled;
    items[to].requestFocus();
    return KeyEventResult.handled;
  }

  /// Whether [focused] is inside a [Select] of the toolbar at [toolbar].
  static bool _inSelect(BuildContext focused, BuildContext toolbar) {
    var found = false;
    focused.visitAncestorElements((element) {
      if (element.widget is Select) {
        found = true;
        return false;
      }
      return element != toolbar;
    });
    return found;
  }

  /// The overflow-menu entry of [child], or null when it has none.
  static _Entry? _entryOf(Widget child) {
    switch (child) {
      case ToolbarItem(:final menuItem?, :final onMenuSelected):
        return _Entry(menuItem, onMenuSelected);
      case ToolbarItem(:final child):
        return _entryOf(child);
      case ToolButton():
        final enabled = !child.disabled && child.onPressed != null;
        return _Entry(
          MenuItem(
            id: child.label,
            label: child.label,
            icon: child.icon,
            shortcut: child.shortcut,
            checked: child.active,
            disabled: !enabled,
            disabledReason: enabled ? null : child.disabledReason,
          ),
          (_) => child.onPressed?.call(),
        );
      case IconButton():
        final enabled =
            !child.disabled && !child.loading && child.onPressed != null;
        return _Entry(
          MenuItem(
            id: child.label,
            label: child.label,
            icon: child.icon,
            shortcut: child.shortcut,
            checked: child.active,
            disabled: !enabled,
            disabledReason: enabled ? null : child.disabledReason,
          ),
          (_) => child.onPressed?.call(),
        );
      case Switch():
        final label = child.label ?? child.semanticLabel;
        if (label == null) return null;
        final onChanged = child.onChanged;
        final enabled = !child.disabled && onChanged != null;
        return _Entry(
          MenuItem(
            id: label,
            label: label,
            checked: child.value,
            disabled: !enabled,
            disabledReason: enabled ? null : child.disabledReason,
          ),
          (_) => onChanged?.call(!child.value),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final floating = widget.variant == ToolbarVariant.floating;
    final Widget row;
    if (floating) {
      row = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space0_5,
        children: widget.children,
      );
    } else {
      row = _bar(context);
    }
    final scoped = _ToolbarScope(variant: widget.variant, child: row);
    final Widget box;
    if (floating) {
      box = DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusLg),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(Toolbar.floatingPadding),
          child: scoped,
        ),
      );
    } else {
      box = Container(
        height: theme.density.toolbarH,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space2,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surfacePanel,
          border: Border(
            bottom: BorderSide(
              color: theme.colors.borderSubtle,
              width: theme.border.borderWidth,
            ),
          ),
        ),
        child: scoped,
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Focus(
        canRequestFocus: false,
        includeSemantics: false,
        skipTraversal: true,
        onKeyEvent: (node, event) => _onKey(context, node, event),
        child: box,
      ),
    );
  }

  /// The bar's row, which collapses when it runs out of room.
  Widget _bar(BuildContext context) {
    final overflowLabel = widget.overflowLabel;
    final children = widget.children;
    final plan = _plan;
    final slots = <Widget>[];
    final entries = <_Entry?>[];
    final kinds = <_SlotKind>[];
    final ids = <Object>[];
    var afterSpacer = false;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      // An item keeps its element, state and focus by its key, as it would
      // in a Row.
      final childKey = child.key;
      final slotKey = childKey == null ? null : ValueKey<Key>(childKey);
      final id = childKey ?? i;
      ids.add(id);
      if (child is ToolbarSpacer) {
        afterSpacer = true;
        kinds.add(_SlotKind.spacer);
        entries.add(null);
        slots.add(
          _ToolbarSlot(
            key: slotKey,
            kind: _SlotKind.spacer,
            overflow: ToolbarOverflow.hide,
            collapsible: false,
            child: child,
          ),
        );
        continue;
      }
      if (child is ToolbarSeparator) {
        kinds.add(_SlotKind.separator);
        entries.add(null);
        slots.add(
          _ToolbarSlot(
            key: slotKey,
            kind: _SlotKind.separator,
            overflow: ToolbarOverflow.hide,
            collapsible: false,
            child: child,
          ),
        );
        continue;
      }
      final entry = _entryOf(child);
      final explicit = child is ToolbarItem ? child.overflow : null;
      final overflow =
          explicit ??
          (entry == null
              ? ToolbarOverflow.hide
              : (afterSpacer ? ToolbarOverflow.late : ToolbarOverflow.auto));
      final inner = child is ToolbarItem ? child.child : child;
      final collapsible =
          inner is ToolButton &&
          inner.showLabel &&
          inner.icon != null &&
          inner.layout == ToolButtonLayout.inline;
      kinds.add(_SlotKind.item);
      entries.add(entry);
      slots.add(
        _ToolbarSlot(
          key: slotKey,
          kind: _SlotKind.item,
          overflow: overflow,
          collapsible: collapsible,
          // Out of the row, out of focus traversal (only focusability:
          // `descendantsAreTraversable` would stick to the items' own nodes
          // as `skipTraversal`).
          child: Focus(
            focusNode: _slotNode(id),
            canRequestFocus: false,
            skipTraversal: true,
            descendantsAreFocusable: plan.shows(id),
            includeSemantics: false,
            child: TickerMode(
              enabled: plan.shows(id),
              // An item out of the row closes the popovers it opened: they
              // would float over nothing.
              child: PopoverAnchorVisibility(
                visible: plan.shows(id),
                child: CollapsedLabelScope(
                  hidden: plan.compact.contains(id),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }
    _slotIds = ids;
    _dropStaleNodes();
    if (overflowLabel != null) {
      slots.add(
        _ToolbarSlot(
          key: const ValueKey<String>('Toolbar overflow'),
          kind: _SlotKind.overflowButton,
          overflow: ToolbarOverflow.hide,
          collapsible: false,
          child: Focus(
            focusNode: _overflowSlot,
            canRequestFocus: false,
            skipTraversal: true,
            descendantsAreFocusable: plan.hasOverflow,
            includeSemantics: false,
            child: _overflowButton(overflowLabel, entries, kinds, ids),
          ),
        ),
      );
    }
    return _ToolbarRow(
      spacing: context.ferman.space.space0_5,
      textDirection: Directionality.of(context),
      onPlan: _onPlan,
      children: slots,
    );
  }

  Widget _overflowButton(
    String label,
    List<_Entry?> entries,
    List<_SlotKind> kinds,
    List<Object> ids,
  ) {
    final items = <MenuItem>[];
    final handlers = Map<MenuItem, VoidCallback>.identity();
    void register(MenuItem item, _Entry entry) {
      handlers[item] = () => entry.onSelected?.call(item);
      for (final sub in item.submenu ?? const <MenuItem>[]) {
        register(sub, entry);
      }
    }

    int? last;
    for (var index = 0; index < ids.length; index++) {
      if (!_plan.overflowed.contains(ids[index])) continue;
      final entry = entries[index];
      if (entry == null) continue;
      if (last != null) {
        final between = kinds.sublist(last + 1, index);
        if (between.any(
          (kind) => kind == _SlotKind.separator || kind == _SlotKind.spacer,
        )) {
          items.add(const MenuItem.divider());
        }
      }
      items.add(entry.item);
      register(entry.item, entry);
      last = index;
    }
    final open = _menuOpen && items.isNotEmpty;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (node, event) {
        if (!_overflowNode.hasPrimaryFocus ||
            !_menuKey.accepts(event, HardwareKeyboard.instance)) {
          return KeyEventResult.ignored;
        }
        if (!_menuOpen) setState(() => _menuOpen = true);
        return KeyEventResult.handled;
      },
      child: Popover(
        open: open,
        surface: false,
        onDismiss: _closeMenu,
        anchor: MergeSemantics(
          child: Semantics(
            expanded: open,
            child: ToolButton(
              icon: IconName.ellipsis,
              label: label,
              showLabel: false,
              focusNode: _overflowNode,
              onPressed: _toggleMenu,
            ),
          ),
        ),
        child: Menu(
          autofocus: true,
          semanticLabel: label,
          items: items,
          onSelected: (item) {
            final handler = handlers[item];
            _closeMenu();
            handler?.call();
          },
          onClose: _closeMenu,
        ),
      ),
    );
  }

  static const SingleActivator _menuKey = SingleActivator(
    LogicalKeyboardKey.arrowDown,
  );
}

/// Tells the toolbar parts which variant they are in.
class _ToolbarScope extends InheritedWidget {
  const new({required this.variant, required super.child});

  final ToolbarVariant variant;

  static ToolbarVariant of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToolbarScope>()?.variant ??
      ToolbarVariant.bar;

  /// Whether [context] is in a bar's own row, which sizes its spacers
  /// itself, rather than in a `Row`.
  static bool inBar(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToolbarScope>()?.variant ==
      ToolbarVariant.bar;

  @override
  bool updateShouldNotify(_ToolbarScope oldWidget) =>
      variant != oldWidget.variant;
}

/// What the bar's row knows of a child.
class _ToolbarParentData extends ContainerBoxParentData<RenderBox> {
  _SlotKind kind = _SlotKind.item;
  ToolbarOverflow overflow = ToolbarOverflow.auto;
  bool collapsible = false;
}

/// Marks a child of the bar's row with what it is.
class _ToolbarSlot extends ParentDataWidget<_ToolbarParentData> {
  const new({
    required this.kind,
    required this.overflow,
    required this.collapsible,
    required super.child,
    super.key,
  });

  final _SlotKind kind;
  final ToolbarOverflow overflow;
  final bool collapsible;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _ToolbarParentData;
    if (data.kind == kind &&
        data.overflow == overflow &&
        data.collapsible == collapsible) {
      return;
    }
    data
      ..kind = kind
      ..overflow = overflow
      ..collapsible = collapsible;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ToolbarRow;
}

/// The bar's row: lays the items out 2 px apart and collapses them when it
/// runs out of room (see [Toolbar]).
class _ToolbarRow extends MultiChildRenderObjectWidget {
  const new({
    required this.spacing,
    required this.textDirection,
    required this.onPlan,
    super.children,
  });

  final double spacing;
  final TextDirection textDirection;
  final ValueChanged<_ToolbarPlan> onPlan;

  @override
  _RenderToolbarRow createRenderObject(BuildContext context) =>
      _RenderToolbarRow(
        spacing: spacing,
        textDirection: textDirection,
        onPlan: onPlan,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderToolbarRow renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..textDirection = textDirection
      ..onPlan = onPlan;
  }
}

class _RenderToolbarRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ToolbarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ToolbarParentData> {
  new({
    required this._spacing,
    required this._textDirection,
    required this.onPlan,
  });

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  ValueChanged<_ToolbarPlan> onPlan;

  /// The children shown, in logical order.
  List<RenderBox> _shown = const [];

  /// Whether even the most collapsed row is wider than the bar.
  bool _clipped = false;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ToolbarParentData) {
      child.parentData = _ToolbarParentData();
    }
  }

  static _ToolbarParentData _data(RenderBox child) =>
      child.parentData! as _ToolbarParentData;

  List<_Measure> _measure(List<RenderBox> children, double height) {
    final measures = <_Measure>[];
    for (final child in children) {
      final data = _data(child);
      final full = data.kind == _SlotKind.spacer
          ? 0.0
          : child.getMaxIntrinsicWidth(height);
      measures.add((
        kind: data.kind,
        overflow: data.overflow,
        collapsible: data.collapsible,
        full: full,
        compact: data.collapsible ? child.getMinIntrinsicWidth(height) : full,
      ));
    }
    return measures;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = getChildrenAsList()
        .where((child) => _data(child).kind != _SlotKind.overflowButton)
        .toList();
    var width = spacing * math.max(0, children.length - 1);
    for (final child in children) {
      if (_data(child).kind == _SlotKind.spacer) continue;
      width += child.getMaxIntrinsicWidth(height);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    var height = 0.0;
    for (final child in getChildrenAsList()) {
      height = math.max(height, child.getMinIntrinsicHeight(double.infinity));
    }
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    var height = 0.0;
    for (final child in getChildrenAsList()) {
      height = math.max(height, child.getMaxIntrinsicHeight(double.infinity));
    }
    return height;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(constraints.maxHeight);
    return constraints.constrain(Size(width, computeMaxIntrinsicHeight(width)));
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final all = getChildrenAsList();
    final button = all
        .where((child) => _data(child).kind == _SlotKind.overflowButton)
        .firstOrNull;
    final children = [
      for (final child in all)
        if (_data(child).kind != _SlotKind.overflowButton) child,
    ];
    final maxHeight = constraints.maxHeight;
    final measures = _measure(children, maxHeight);
    final available = constraints.maxWidth;
    final plan = available.isFinite
        ? _ToolbarPlan.fit(
            measures,
            spacing,
            button?.getMaxIntrinsicWidth(maxHeight),
            available,
          )
        : _ToolbarPlan.none;
    final sequence = _ToolbarPlan.sequence(measures, plan);
    final shown = [
      for (final entry in sequence)
        if (entry == -1) ?button else children[entry],
    ];

    // The shown items at their width, compact ones at their compact width.
    final loose = BoxConstraints(maxHeight: maxHeight);
    var used = spacing * math.max(0, shown.length - 1);
    var spacers = 0;
    var height = 0.0;
    for (final entry in sequence) {
      if (entry != -1 && measures[entry].kind == _SlotKind.spacer) {
        spacers++;
        continue;
      }
      final child = entry == -1 ? button! : children[entry];
      final childConstraints = entry != -1 && plan.compact.contains(entry)
          ? BoxConstraints(
              maxWidth: measures[entry].compact,
              maxHeight: maxHeight,
            )
          : loose;
      child.layout(childConstraints, parentUsesSize: true);
      used += child.size.width;
      height = math.max(height, child.size.height);
    }
    final free = available.isFinite ? math.max(0, available - used) : 0;
    for (final entry in sequence) {
      if (entry == -1 || measures[entry].kind != _SlotKind.spacer) continue;
      children[entry].layout(
        BoxConstraints.tightFor(width: free / spacers, height: 0),
        parentUsesSize: true,
      );
    }
    // The others keep a size, so focus and semantics can ask for their
    // rectangle, but are neither painted nor hit-tested.
    final shownSet = shown.toSet();
    for (final child in all) {
      if (shownSet.contains(child)) continue;
      child.layout(loose, parentUsesSize: true);
    }

    size = constraints.constrain(
      Size(available.isFinite ? available : used, height),
    );
    _clipped = used > size.width + 0.01;
    final rtl = textDirection == TextDirection.rtl;
    var x = 0.0;
    for (final child in shown) {
      final dy = (size.height - child.size.height) / 2;
      final dx = rtl ? size.width - x - child.size.width : x;
      _data(child).offset = Offset(dx, dy);
      x += child.size.width + spacing;
    }
    // Out of the row: at the start edge, out of sight.
    for (final child in all) {
      if (shownSet.contains(child)) continue;
      _data(child).offset = Offset(
        rtl ? size.width - child.size.width : 0,
        (size.height - child.size.height) / 2,
      );
    }
    _shown = shown;
    onPlan(plan);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintShown(PaintingContext context, Offset offset) {
      for (final child in _shown) {
        context.paintChild(child, offset + _data(child).offset);
      }
    }

    if (_clipped) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        paintShown,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      paintShown(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _shown.reversed) {
      final hit = result.addWithPaintOffset(
        offset: _data(child).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    _shown.forEach(visitor);
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// The 1 × 20 vertical rule between tool groups, the design-system
/// `ToolbarSeparator` (`components/navigation/navigation.css`,
/// `.fm-toolbar__sep`).
///
/// It has 6 px of space on each side in a bar and 3 px in a floating
/// toolbar. It is decorative: the design's `role="separator"` has no
/// Flutter role, and the groups it separates are not announced.
class ToolbarSeparator extends StatelessWidget {
  /// A separator.
  const new({super.key});

  /// `.fm-toolbar__sep` `height: 20px`.
  static const double height = 20;

  /// `.fm-toolbar--floating .fm-toolbar__sep` `margin: 0 3px`.
  static const double floatingMargin = 3;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final floating = _ToolbarScope.of(context) == ToolbarVariant.floating;
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: floating ? floatingMargin : theme.space.space1_5,
        ),
        child: SizedBox(
          width: theme.border.borderWidth,
          height: height,
          child: ColoredBox(color: theme.colors.borderDefault),
        ),
      ),
    );
  }
}

/// A flexible gap that pushes the toolbar items after it to the end, the
/// design-system `ToolbarSpacer` (`components/navigation/navigation.css`,
/// `.fm-toolbar__spacer`, `flex: 1`).
///
/// It must be a direct child of a [Toolbar]. Items after it are the row's
/// end actions, which leave a narrow bar last ([ToolbarOverflow.late]).
class ToolbarSpacer extends StatelessWidget {
  /// A spacer.
  const new({super.key});

  // A bar's row gives it the free width itself; a floating toolbar is a
  // Row.
  @override
  Widget build(BuildContext context) => _ToolbarScope.inBar(context)
      ? const SizedBox.shrink()
      : const Expanded(child: SizedBox.shrink());
}

/// A labelled group of tools inside a [Toolbar], the design-system
/// `ToolbarGroup` (`components/navigation/navigation.css`,
/// `.fm-toolbar__group`).
///
/// Its [children] sit 2 px apart. For screen readers it is a container
/// named [semanticLabel] (the design's `role="group"`; Flutter has no group
/// role). No board uses it yet (tier 2). In a narrow bar it hides, or
/// moves into the overflow menu when wrapped in a [ToolbarItem] with an
/// entry, as one item.
class ToolbarGroup extends StatelessWidget {
  /// A group of [children] named [semanticLabel].
  const new({required this.semanticLabel, required this.children, super.key});

  /// The accessible name of the group (the design's `label`).
  final String semanticLabel;

  /// The tools in the group.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: semanticLabel,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.ferman.space.space0_5,
      children: children,
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('semanticLabel', semanticLabel))
      ..add(IntProperty('children', children.length));
  }
}
