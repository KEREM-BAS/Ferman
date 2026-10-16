import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Forces interaction states onto the Ferman components below it, as the
/// design's state sheet does with `data-fm-force` (`fm-additions.css`, the
/// "Interactive states" matrix in `DS additions.dc.html`).
///
/// The component gallery and the goldens use it to draw a hover, pressed or
/// focus-visible look without a pointer or keyboard. Every component built
/// on `FermanInteractive` adds these states to the ones it tracks; the app
/// itself never places one.
///
/// [WidgetState.focused] stands for the design's focus-visible state, as it
/// does throughout the component library.
class FermanForcedStates extends InheritedWidget {
  /// Forces [states] onto the components in [child].
  const new({required this.states, required super.child, super.key});

  /// The states to force; empty forces nothing.
  final Set<WidgetState> states;

  /// The forced states at [context], empty when no [FermanForcedStates] is
  /// above it.
  static Set<WidgetState> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FermanForcedStates>()
          ?.states ??
      const <WidgetState>{};

  @override
  bool updateShouldNotify(FermanForcedStates oldWidget) =>
      !setEquals(states, oldWidget.states);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<WidgetState>('states', states));
  }
}
