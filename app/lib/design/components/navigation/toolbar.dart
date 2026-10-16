import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How a [Toolbar] is drawn (`.fm-toolbar--bar`, `.fm-toolbar--floating`).
enum ToolbarVariant {
  /// The tool row under the mode bar: full width, `--toolbar-h` tall, on
  /// the panel surface with a bottom border.
  bar,

  /// A raised pill floating over the document (`--shadow-popover`).
  floating,
}

/// A row of tools, the design-system `Toolbar` component
/// (`components/navigation/navigation.css`, `.fm-toolbar`; `Toolbar.jsx`).
///
/// [children] are laid out in a row 2 px apart, in order: tool buttons,
/// icon buttons, selects, segmented controls, [ToolbarSeparator]s between
/// groups, a [ToolbarSpacer] to push the rest to the end, and
/// [ToolbarGroup]s. Pass them directly, not wrapped, so a spacer can
/// expand.
///
/// **Keyboard** (`Toolbar.jsx`): every item stays a Tab stop, and
/// ArrowLeft and ArrowRight move focus to the previous and next item in the
/// visual direction (mirrored in right to left), wrapping. They stop on
/// enabled items and on disabled items that give a reason (which stay
/// focusable, G10), and skip plain disabled ones. Inside a segmented
/// control, tab strip or radio group only its Tab stop is visited, and the
/// group's own arrow keys win while focus is in it. While focus is in a
/// text field the arrows move the caret instead.
///
/// **Semantics:** a container labelled [semanticLabel] that keeps its
/// items as separate nodes. Flutter has no toolbar role.
///
/// Narrow windows (G21) are not handled yet: the row does not collapse to
/// icons or move tools into an overflow menu.
class Toolbar extends StatelessWidget {
  /// A toolbar of [children].
  const new({
    required this.semanticLabel,
    required this.children,
    super.key,
    this.variant = ToolbarVariant.bar,
  });

  /// How the toolbar is drawn.
  final ToolbarVariant variant;

  /// The accessible name of the toolbar (the design's `label`), for
  /// example the localized "Comment tools".
  final String semanticLabel;

  /// The items, in order.
  final List<Widget> children;

  /// `.fm-toolbar--floating` `padding: 3px`.
  static const double floatingPadding = 3;

  KeyEventResult _onKey(BuildContext context, FocusNode node, KeyEvent event) {
    final step = RovingFocus.stepFor(event, Directionality.of(context));
    if (step == null) return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || focused == node) return KeyEventResult.ignored;
    // In a text field the arrows move the caret.
    if (focused.context?.findAncestorStateOfType<EditableTextState>() != null) {
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
    final from = items.indexWhere(
      (item) => item == focused || focused.ancestors.contains(item),
    );
    if (from < 0) return KeyEventResult.ignored;
    final to = RovingFocus.target(from, items.length, step, (_) => true);
    if (to == null) return KeyEventResult.handled;
    items[to].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final floating = variant == ToolbarVariant.floating;
    Widget row = Row(
      mainAxisSize: floating ? MainAxisSize.min : MainAxisSize.max,
      spacing: theme.space.space0_5,
      children: children,
    );
    row = _ToolbarScope(variant: variant, child: row);
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
          padding: const EdgeInsetsDirectional.all(floatingPadding),
          child: row,
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
        child: row,
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Focus(
        canRequestFocus: false,
        includeSemantics: false,
        skipTraversal: true,
        onKeyEvent: (node, event) => _onKey(context, node, event),
        child: box,
      ),
    );
  }

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
      ..add(IntProperty('children', children.length));
  }
}

/// Tells the toolbar parts which variant they are in.
class _ToolbarScope extends InheritedWidget {
  const new({required this.variant, required super.child});

  final ToolbarVariant variant;

  static ToolbarVariant of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToolbarScope>()?.variant ??
      ToolbarVariant.bar;

  @override
  bool updateShouldNotify(_ToolbarScope oldWidget) =>
      variant != oldWidget.variant;
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
/// It must be a direct child of a [Toolbar] (it is an [Expanded]).
class ToolbarSpacer extends StatelessWidget {
  /// A spacer.
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const Expanded(child: SizedBox.shrink());
}

/// A labelled group of tools inside a [Toolbar], the design-system
/// `ToolbarGroup` (`components/navigation/navigation.css`,
/// `.fm-toolbar__group`).
///
/// Its [children] sit 2 px apart. For screen readers it is a container
/// named [semanticLabel] (the design's `role="group"`; Flutter has no group
/// role). No board uses it yet (tier 2).
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
