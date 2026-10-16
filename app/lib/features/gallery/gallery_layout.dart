import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The interaction states the gallery forces, as the design's state sheet
/// does with `data-fm-force` (`DS additions.dc.html`, "Interactive
/// states"). [WidgetState.focused] is the design's focus-visible state.
abstract final class GalleryForced {
  /// The pointer over the control (`hover`).
  static const Set<WidgetState> hover = {WidgetState.hovered};

  /// The pointer down on the control (`pressed`, the sheet's `active`).
  static const Set<WidgetState> pressed = {WidgetState.pressed};

  /// The keyboard focus ring (`focusVisible`, the sheet's `focus`).
  static const Set<WidgetState> focusVisible = {WidgetState.focused};
}

/// A labelled row of specimens that wraps onto more lines when the gallery
/// is narrow, in the reading order of the text direction.
class GalleryRow extends StatelessWidget {
  /// Shows [children] under [label].
  const new({required this.children, super.key, this.label});

  /// What the row varies, such as `variant: primary`; null shows none.
  final String? label;

  /// The specimens.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final label = this.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        if (label != null)
          Text(
            label,
            style: theme.typography.label.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
        Wrap(
          spacing: theme.space.space5,
          runSpacing: theme.space.space4,
          children: children,
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label, defaultValue: null));
  }
}

/// One sample: a caption naming its variant or state (the spec's names)
/// over the component, with [forced] states forced onto it.
///
/// [width] and [height] give the component a bounded box, for the many
/// components that take the width of their parent; without them it takes
/// its own size.
class GallerySpecimen extends StatelessWidget {
  /// Shows [child] under [label].
  const new({
    required this.label,
    required this.child,
    super.key,
    this.forced,
    this.width,
    this.height,
    this.excludeSemantics = false,
  });

  /// The variant or state shown.
  final String label;

  /// The component.
  final Widget child;

  /// The states forced onto [child], or null for none.
  final Set<WidgetState>? forced;

  /// The width of [child]'s box; null lets it size itself.
  final double? width;

  /// The height of [child]'s box; null lets it size itself.
  final double? height;

  /// Whether to leave [child] out of the semantics tree: for samples whose
  /// role needs child nodes (a menu, a tab bar). Where the scrolling list
  /// cuts such a sample at its edge, the list's semantics clip can drop
  /// every child node and keep the container, and Flutter's debug role
  /// check then fails ("a menu cannot be empty"). The app never places
  /// these in a scrolling list.
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    var content = child;
    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }
    final forced = this.forced;
    if (forced != null) {
      content = FermanForcedStates(states: forced, child: content);
    }
    if (excludeSemantics) content = ExcludeSemantics(child: content);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space1_5,
      children: [
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.textTertiary,
          ),
        ),
        content,
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(IterableProperty<WidgetState>('forced', forced, defaultValue: null))
      ..add(DoubleProperty('width', width, defaultValue: null))
      ..add(DoubleProperty('height', height, defaultValue: null))
      ..add(
        FlagProperty(
          'excludeSemantics',
          value: excludeSemantics,
          ifTrue: 'excludes semantics',
        ),
      );
  }
}

/// A box with an [Overlay] of its own, [width] by [height], for open
/// popovers and tooltips: they float inside it, never over the rest of the
/// gallery, and scroll with it.
class GalleryStage extends StatelessWidget {
  /// Places [child] at [alignment] in the box.
  const new({
    required this.width,
    required this.height,
    required this.child,
    super.key,
    this.alignment = AlignmentDirectional.topStart,
  });

  /// The width of the box.
  final double width;

  /// The height of the box: room for [child] and what floats from it.
  final double height;

  /// Where [child] sits.
  final AlignmentGeometry alignment;

  /// The anchor of the floating surface.
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Overlay.wrap(
      child: Align(alignment: alignment, child: child),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('width', width))
      ..add(DoubleProperty('height', height))
      ..add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
  }
}

/// A piece of PDF page for the page-tuned components (PageMark, Highlight,
/// TextEditBox, PdfFormField, Stamp and the sticky-note pin): paper-white
/// in every theme, with the page border, the page filter of the dim theme
/// and the document face as the text style (`--font-doc-sample`, page ink).
///
/// Like the shell's canvas, the page is never mirrored in right to left: it
/// runs left to right, as pages keep their own geometry (ADR 0014), unless
/// [uiDirection] keeps the UI's direction for UI drawn on a page preview
/// (the sidebar's thumbnail badges).
class GalleryPage extends StatelessWidget {
  /// Puts [child] on the page.
  const new({required this.child, super.key, this.uiDirection = false});

  /// What the page shows.
  final Widget child;

  /// Whether [child] keeps the UI's text direction instead of the page's
  /// left to right.
  final bool uiDirection;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final doc = theme.typeScale.fontDocSample;
    Widget page = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.pageColors.pageBg,
        border: Border.all(
          color: theme.colors.pageBorder,
          width: theme.border.borderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.space.space5),
        child: DefaultTextStyle.merge(
          style: theme.typography.prose.copyWith(
            fontFamily: doc.family,
            fontFamilyFallback: doc.fallback,
            color: theme.ramps.paper900,
          ),
          child: uiDirection
              ? child
              : Directionality(textDirection: TextDirection.ltr, child: child),
        ),
      ),
    );
    final filter = theme.pageColorFilter;
    if (filter != null) page = ColorFiltered(colorFilter: filter, child: page);
    return page;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      FlagProperty(
        'uiDirection',
        value: uiDirection,
        ifTrue: 'keeps the UI direction',
      ),
    );
  }
}

/// A sample surface in [color] (the inverse surface under inverse key
/// caps, the accent under an on-accent spinner), with small corners.
class GallerySurface extends StatelessWidget {
  /// Puts [child] on [color].
  const new({required this.color, required this.child, super.key});

  /// The surface colour.
  final Color color;

  /// What sits on it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(theme.radius.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.space.space2),
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color));
  }
}

/// A short note under a row: why a state is shown the way it is.
class GalleryNote extends StatelessWidget {
  /// Shows [text].
  const new(this.text, {super.key});

  /// The note.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Text(
      text,
      style: theme.typography.caption.copyWith(
        color: theme.colors.textSecondary,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text));
  }
}

/// The rows of one component's section, stacked.
class GalleryBody extends StatelessWidget {
  /// Stacks [children].
  const new({required this.children, super.key});

  /// The rows and notes.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: context.ferman.space.space6,
    children: children,
  );
}

/// Keeps a sample's value, so a controlled component in the gallery works
/// when the viewer clicks or types: [builder] gets the value and a setter.
class GalleryValue<T> extends StatefulWidget {
  /// Starts from [initial].
  const new({required this.initial, required this.builder, super.key});

  /// The first value.
  final T initial;

  /// Builds the sample for the current value; calling the setter changes
  /// it.
  final Widget Function(BuildContext context, T value, ValueChanged<T> set)
  builder;

  @override
  State<GalleryValue<T>> createState() => _GalleryValueState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('initial', initial));
  }
}

class _GalleryValueState<T> extends State<GalleryValue<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _value,
    (value) => setState(() => _value = value),
  );
}

/// A wide specimen that scrolls sideways when the gallery is narrower than
/// it (a tool row with labels), instead of overflowing.
class GallerySideScroll extends StatelessWidget {
  /// Lets [child] scroll sideways.
  const new({required this.child, super.key});

  /// The wide specimen.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: child);
}
