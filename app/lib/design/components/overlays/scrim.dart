import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The dimmed layer behind a modal, the internal `Scrim` of the component
/// spec (`components/overlays/overlays.css`, `.fm-scrim`).
///
/// It fills the space it is given with `--surface-scrim` (38 % warm black;
/// 56 % black in dark), fading in over `--dur-base` (at once with reduced
/// motion), and centres [child] inside 16 px of padding. With [top] (the
/// command palette, `.fm-scrim--top`) the tint is lighter and [child] sits
/// at the top, 14 % of the height down. There is no backdrop blur anywhere
/// (readme "Transparency and blur").
///
/// A pointer down on the scrim itself, not on [child], calls [onDismiss]
/// (the bundle's `onMouseDown` on the scrim). For screen readers the scrim
/// is a dismiss target named by [dismissLabel] when both are set, and is
/// silent otherwise, as Flutter's modal barrier is.
class Scrim extends StatelessWidget {
  /// Dims the space behind [child].
  const new({
    required this.child,
    super.key,
    this.top = false,
    this.onDismiss,
    this.dismissLabel,
  });

  /// `.fm-scrim--top` `background: rgba(20, 19, 17, 0.18)`.
  static const Color topLight = Color(0x2E141311);

  /// `[data-theme="dark"] .fm-scrim--top` `background: rgba(0, 0, 0, 0.4)`.
  static const Color topDark = Color(0x66000000);

  /// `.fm-scrim--top` `padding-top: 14vh`, as a fraction of the height.
  static const double topOffset = 0.14;

  /// Whether this is the palette's lighter scrim with [child] at the top.
  final bool top;

  /// Called on a pointer down on the scrim outside [child].
  final VoidCallback? onDismiss;

  /// The accessible name of the scrim as a dismiss target ("Close").
  final String? dismissLabel;

  /// The modal surface.
  final Widget child;

  /// The scrim colour in [theme] for [top].
  static Color colorOf(FermanTheme theme, {required bool top}) {
    if (!top) return theme.colors.surfaceScrim;
    return theme.isDark ? topDark : topLight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final dismiss = onDismiss;
    final label = dismissLabel;
    Widget barrier = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motion.durBase,
      curve: theme.motion.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: ColoredBox(color: colorOf(theme, top: top)),
    );
    barrier = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: dismiss == null ? null : (_) => dismiss(),
      child: barrier,
    );
    barrier = dismiss != null && label != null
        ? Semantics(
            label: label,
            onTap: dismiss,
            onDismiss: dismiss,
            child: barrier,
          )
        : ExcludeSemantics(child: barrier);
    final edge = theme.space.space4;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: barrier,
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              edge,
              top && constraints.hasBoundedHeight
                  ? constraints.maxHeight * topOffset
                  : edge,
              edge,
              edge,
            ),
            child: Align(
              alignment: top
                  ? AlignmentDirectional.topCenter
                  : AlignmentDirectional.center,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('top', value: top, ifTrue: 'top'))
      ..add(
        FlagProperty(
          'dismissible',
          value: onDismiss != null,
          ifTrue: 'dismissible',
        ),
      )
      ..add(StringProperty('dismissLabel', dismissLabel, defaultValue: null));
  }
}
