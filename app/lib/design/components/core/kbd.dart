import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How a [Kbd] draws its key caps (`.fm-kbd`, `.fm-kbd--plain`,
/// `.fm-kbd--inverse`).
enum KbdTone {
  /// Raised caps with a border and a thicker bottom edge, in the secondary
  /// text colour. The design's `default`.
  standard,

  /// Bare characters in the tertiary text colour, for menus.
  plain,

  /// Bare characters in the inverse text colour at 68 % opacity, for
  /// tooltips.
  inverse,
}

/// A keyboard shortcut as key caps, the design-system `Kbd` component
/// (`components/core/core.css`, `.fm-kbd`).
///
/// [keys] are the caps already resolved for the platform from the one
/// shortcut table (⌘ ⌥ ⇧ on macOS; Ctrl, Alt, Shift on Windows and Linux).
/// Shortcuts appear only in tooltips and menus, never inside sentences.
///
/// For screen readers the caps are read as one label, the caps joined by
/// spaces: screen readers speak the modifier symbols themselves (VoiceOver
/// says "command" for ⌘). Pass [semanticLabel] to give a spoken form
/// instead.
class Kbd extends StatelessWidget {
  /// Shows [keys] as caps.
  const new(
    this.keys, {
    super.key,
    this.tone = KbdTone.standard,
    this.semanticLabel,
  });

  /// The key caps, one per key, already resolved for the platform.
  final List<String> keys;

  /// How the caps are drawn.
  final KbdTone tone;

  /// The spoken form of the shortcut; null joins [keys] with spaces.
  final String? semanticLabel;

  /// `.fm-kbd__key` `min-width` and `height`.
  static const double capExtent = 18;

  /// `.fm-kbd__key` `border-radius`.
  static const double capRadius = 3;

  /// `.fm-kbd__key` horizontal padding of a raised cap.
  static const double capPadding = 4;

  /// Horizontal padding of a bare cap (plain, inverse).
  static const double barePadding = 1;

  /// `.fm-kbd__key` `border-bottom-width` of a raised cap.
  static const double capBottomBorder = 2;

  /// `.fm-kbd` `gap` between caps.
  static const double gap = 2;

  /// `.fm-kbd--inverse .fm-kbd__key` `opacity`.
  static const double inverseOpacity = 0.68;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final color = switch (tone) {
      KbdTone.standard => colors.textSecondary,
      KbdTone.plain => colors.textTertiary,
      KbdTone.inverse => colors.textInverse,
    };
    final style = TextStyle(
      fontFamily: theme.typography.body.fontFamily,
      fontFamilyFallback: theme.typography.body.fontFamilyFallback,
      fontSize: theme.typeScale.sizeXs,
      fontWeight: theme.typeScale.weightRegular,
      height: 1,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      locale: theme.typography.body.locale,
    );
    Widget cap(String key) {
      // A cap is one key: it reads left to right in every UI direction, so a
      // bracket or arrow on it is never mirrored ("⌘]" stays "]"). The row of
      // caps still follows the UI direction, as a12-1ar draws "K ⌘".
      final text = Text(
        key,
        style: style,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      if (tone != KbdTone.standard) {
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: barePadding,
          ),
          child: text,
        );
      }
      final side = BorderSide(
        color: colors.borderDefault,
        width: theme.border.borderWidth,
      );
      return Container(
        constraints: const BoxConstraints(
          minWidth: capExtent,
          minHeight: capExtent,
          maxHeight: capExtent,
        ),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: capPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: const BorderRadius.all(Radius.circular(capRadius)),
          border: BorderDirectional(
            top: side,
            start: side,
            end: side,
            bottom: side.copyWith(width: capBottomBorder),
          ),
        ),
        child: text,
      );
    }

    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [for (final key in keys) cap(key)],
    );
    if (tone == KbdTone.inverse) {
      row = Opacity(opacity: inverseOpacity, child: row);
    }
    return Semantics(
      container: true,
      label: semanticLabel ?? keys.join(' '),
      child: ExcludeSemantics(child: row),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<String>('keys', keys))
      ..add(EnumProperty<KbdTone>('tone', tone, defaultValue: KbdTone.standard))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}
