import 'package:ferman/design/components/foundation/anchored_layout.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A raised surface anchored under its trigger, the internal `Popover` of
/// the component spec (`components/forms/forms.css`, `.fm-popover`). The
/// Select list, the ColorPicker and FontPicker popovers, and the surfaces
/// that draw their own shell (Menu, DatePicker, MentionList) all open
/// through it. Never a Material popup (ADR 0011).
///
/// While [open], [child] floats in the nearest [Overlay], 4 px under
/// [anchor] with its start edges lined up (`top: calc(100% + 4px);
/// inset-inline-start: 0`), flipping above the anchor when there is no
/// room below and kept inside the overlay ([FermanAnchoredLayout]). The
/// surface is the raised colour with medium corners and the popover shadow,
/// and it rises in over `--dur-base` (at once with reduced motion). With
/// [surface] false the child is placed as it is, for components that draw
/// their own shell and entrance.
///
/// A pointer down outside both the anchor and the popover, or Escape while
/// focus is in either, calls [onDismiss]; the owner closes the popover and
/// returns focus to its trigger. The anchor itself does not count as
/// outside, so a trigger can toggle the popover.
///
/// The popover's semantics come from [child] (a dialog or a list, per
/// use).
class Popover extends StatefulWidget {
  /// Anchors [child] to [anchor].
  const new({
    required this.open,
    required this.anchor,
    required this.child,
    super.key,
    this.onDismiss,
    this.surface = true,
    this.matchAnchorWidth = false,
  });

  /// `.fm-popover` `top: calc(100% + 4px)`: the gap under the anchor.
  static const double gap = 4;

  /// `fm-rise-in`: how far the surface rises while it fades in.
  static const double riseDistance = 4;

  /// Whether the popover is shown.
  final bool open;

  /// The trigger the popover hangs from.
  final Widget anchor;

  /// The content of the popover.
  final Widget child;

  /// Called on a pointer down outside the anchor and the popover, or on
  /// Escape.
  final VoidCallback? onDismiss;

  /// Whether to draw the popover surface around [child] and animate it in;
  /// false for children that draw their own. Not in the spec.
  final bool surface;

  /// Whether the popover is at least as wide as the anchor (the Select
  /// list). Not in the spec.
  final bool matchAnchorWidth;

  /// The tap-region group of the nearest open [Popover] above [context],
  /// or null. A surface that opens from inside a popover in an overlay of
  /// its own (a submenu) wraps itself in a `TapRegion` with this group, so
  /// a click on it does not count as outside the popover.
  static Object? groupOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PopoverGroup>()?.group;

  @override
  State<Popover> createState() => _PopoverState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        FlagProperty('open', value: open, ifTrue: 'open', ifFalse: 'closed'),
      )
      ..add(FlagProperty('surface', value: surface, ifFalse: 'no surface'))
      ..add(
        FlagProperty(
          'matchAnchorWidth',
          value: matchAnchorWidth,
          ifTrue: 'matches the anchor width',
        ),
      );
  }
}

class _PopoverState extends State<Popover> {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'Popover',
  );

  /// The tap-region group of the anchor and the popover.
  final Object _group = Object();

  @override
  void initState() {
    super.initState();
    // Not attached yet, so this only records that the portal starts shown.
    if (widget.open) _portal.show();
  }

  @override
  void didUpdateWidget(Popover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      // The overlay cannot be shown or hidden during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;
    if (widget.open && !_portal.isShowing) {
      _portal.show();
    } else if (!widget.open && _portal.isShowing) {
      _portal.hide();
    }
  }

  void _dismiss() {
    if (widget.open) widget.onDismiss?.call();
  }

  Widget _overlay(BuildContext context, OverlayChildLayoutInfo info) {
    final theme = context.ferman;
    final anchor = FermanAnchoredLayout.anchorRect(info);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    var content = widget.child;
    if (widget.surface) {
      content = PopoverSurface(child: content);
    }
    if (widget.matchAnchorWidth) {
      content = ConstrainedBox(
        constraints: BoxConstraints(minWidth: anchor.width),
        child: content,
      );
    }
    return CustomSingleChildLayout(
      delegate: FermanAnchoredLayout(
        anchor: anchor,
        side: AnchorSide.bottom,
        alignment: rtl ? AnchorAlignment.trailing : AnchorAlignment.leading,
        gap: Popover.gap,
      ),
      child: _PopoverGroup(
        group: _group,
        child: TapRegion(
          groupId: _group,
          // A click anywhere on the popover, its padding and headings
          // included, is inside it and never reaches what lies beneath.
          behavior: HitTestBehavior.opaque,
          onTapOutside: (_) => _dismiss(),
          child: widget.surface
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: theme.motion.durBase,
                  curve: theme.motion.easeOut,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, Popover.riseDistance * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (widget.open)
          const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: _overlay,
        child: TapRegion(
          groupId: _group,
          behavior: HitTestBehavior.opaque,
          child: widget.anchor,
        ),
      ),
    );
  }
}

/// Carries the tap-region group of a [Popover] to its content.
class _PopoverGroup extends InheritedWidget {
  const new({required this.group, required super.child});

  final Object group;

  @override
  bool updateShouldNotify(_PopoverGroup oldWidget) => group != oldWidget.group;
}

/// The popover shell (`.fm-popover`): the raised surface colour, medium
/// corners and the popover shadow. [Popover] draws it; the components
/// that open in a popover without it use it for the same look.
class PopoverSurface extends StatelessWidget {
  /// Draws the shell around [child].
  const new({required this.child, super.key, this.radius});

  /// The content.
  final Widget child;

  /// The corner radius; null takes `--radius-md`.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceRaised,
        borderRadius: BorderRadius.all(
          Radius.circular(radius ?? theme.radius.radiusMd),
        ),
        boxShadow: theme.elevation.shadowPopover,
      ),
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('radius', radius, defaultValue: null));
  }
}

/// The section heading inside a popover (`.fm-popover__section`): label
/// type in the tertiary colour with label tracking, 8 px above, 10 px at
/// the sides and 4 px below.
class PopoverSection extends StatelessWidget {
  /// Shows [label] as a section heading.
  const new(this.label, {super.key});

  /// The heading text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final style = theme.typography.label;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        theme.space.space2_5,
        theme.space.space2,
        theme.space.space2_5,
        theme.space.space1,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: style.copyWith(
            color: theme.colors.textTertiary,
            letterSpacing: theme.typeScale.trackingLabel * style.fontSize!,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
  }
}
