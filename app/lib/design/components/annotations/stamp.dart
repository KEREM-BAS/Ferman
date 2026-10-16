import 'dart:math' as math;

import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The ink of a [Stamp] (`.fm-stamp--seal`, `--ink`, `--green`,
/// `--neutral`).
enum StampTone {
  /// Seal red (`--seal-500`), reserved for stamps and brand moments.
  seal,

  /// Ink blue (`--ink-600`).
  ink,

  /// Green (`--green-600`).
  green,

  /// Dark neutral (`--paper-800`).
  neutral,
}

/// A rubber-stamp annotation, the design-system `Stamp` component
/// (`components/annotations/annotations.css`, `.fm-stamp`; `Stamp.jsx`).
///
/// [label] in uppercase, semibold, [fontSize] tall with 0.14 em tracking,
/// over an optional [meta] line (9 px medium, tabular figures, not
/// uppercased), inside a 2 px border with 3 px corners and a 1 px outline
/// 2 px outside it, all in [tone]'s ink. The stamp is turned by [rotation]
/// degrees, drawn at 90 % opacity and multiplied with the page
/// (`mix-blend-mode: multiply`), so text under it shows through as under
/// real ink. Document colours: the same in both themes.
///
/// The label is uppercased with the casing rules of [locale] (Turkish
/// turns i into İ), else of the UI locale (ARCHITECTURE §11.2); the design
/// default "Approved" is copy, so the screens pass the localized label.
///
/// For screen readers the stamp is an image labelled [semanticLabel]
/// (the bundle's English "Stamp: <label>, <meta>", localized by the
/// screen), or by the label and meta when none is given.
class Stamp extends StatelessWidget {
  /// Creates a stamp reading [label].
  const new({
    required this.label,
    super.key,
    this.tone = StampTone.seal,
    this.meta,
    this.rotation = -3,
    this.locale,
    this.fontSize = 18,
    this.semanticLabel,
  });

  /// `.fm-stamp` `padding: 7px 14px 6px`, top.
  static const double paddingTop = 7;

  /// `.fm-stamp` `padding: 7px 14px 6px`, sides.
  static const double paddingX = 14;

  /// `.fm-stamp` `padding: 7px 14px 6px`, bottom.
  static const double paddingBottom = 6;

  /// `.fm-stamp` `gap: 3px` between the label and the meta line.
  static const double gap = 3;

  /// `.fm-stamp` `border: 2px solid currentColor`.
  static const double borderWidth = 2;

  /// `.fm-stamp` `border-radius: 3px`.
  static const double radius = 3;

  /// `.fm-stamp` `outline: 1px solid currentColor`.
  static const double outlineWidth = 1;

  /// `.fm-stamp` `outline-offset: 2px`.
  static const double outlineOffset = 2;

  /// `.fm-stamp` `letter-spacing: 0.14em`.
  static const double tracking = 0.14;

  /// `.fm-stamp` `opacity: 0.9`.
  static const double opacity = 0.9;

  /// `.fm-stamp__meta` `font: var(--weight-medium) 9px/1.2`.
  static const double metaFontSize = 9;

  /// `.fm-stamp__meta` line height.
  static const double metaHeight = 1.2;

  /// `.fm-stamp__meta` `letter-spacing: 0.04em`.
  static const double metaTracking = 0.04;

  /// The stamp's text, uppercased when drawn.
  final String label;

  /// The ink.
  final StampTone tone;

  /// The line under the label (a name and date); null shows none.
  final String? meta;

  /// The turn in degrees; negative turns anticlockwise.
  final double rotation;

  /// The language whose casing rules uppercase [label] (the bundle's
  /// `lang`); null takes the UI locale.
  final Locale? locale;

  /// The label's font size (the bundle's `size`).
  final double fontSize;

  /// The accessible name; null reads [label] and [meta]. Not a
  /// design-system prop.
  final String? semanticLabel;

  /// The ink of [tone] in [theme].
  static Color inkOf(StampTone tone, FermanTheme theme) {
    final ramps = theme.ramps;
    return switch (tone) {
      StampTone.seal => ramps.seal500,
      StampTone.ink => ramps.ink600,
      StampTone.green => ramps.green600,
      StampTone.neutral => ramps.paper800,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final ink = inkOf(tone, theme);
    final textLocale = locale ?? Localizations.maybeLocaleOf(context);
    final casing = textLocale == null
        ? LocaleCasing.root
        : LocaleCasing.forLocale(textLocale);
    final base = theme.typography.body.copyWith(color: ink, locale: textLocale);
    final meta = this.meta;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        Text(
          casing.upper(label),
          maxLines: 1,
          softWrap: false,
          style: base.copyWith(
            fontSize: fontSize,
            height: 1,
            fontWeight: theme.typeScale.weightSemibold,
            letterSpacing: tracking * fontSize,
          ),
        ),
        if (meta != null)
          Text(
            meta,
            maxLines: 1,
            softWrap: false,
            style: base.copyWith(
              fontSize: metaFontSize,
              height: metaHeight,
              fontWeight: theme.typeScale.weightMedium,
              letterSpacing: metaTracking * metaFontSize,
              fontFeatures: theme.typeScale.numericTabular,
            ),
          ),
      ],
    );
    final stamp = CustomPaint(
      foregroundPainter: _StampOutlinePainter(ink),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          paddingX,
          paddingTop,
          paddingX,
          paddingBottom,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: ink, width: borderWidth),
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
        ),
        child: content,
      ),
    );
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel ?? [label, ?meta].join(', '),
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: rotation * math.pi / 180,
          child: _MultiplyLayer(child: stamp),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(EnumProperty<StampTone>('tone', tone, defaultValue: StampTone.seal))
      ..add(StringProperty('meta', meta, defaultValue: null))
      ..add(DoubleProperty('rotation', rotation, defaultValue: -3))
      ..add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null))
      ..add(DoubleProperty('fontSize', fontSize, defaultValue: 18))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// Strokes the stamp's outline: 1 px, [Stamp.outlineOffset] outside the
/// border, following its corners.
class _StampOutlinePainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const outset = Stamp.outlineOffset + Stamp.outlineWidth / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(outset),
        const Radius.circular(Stamp.radius + outset),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Stamp.outlineWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_StampOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Paints its child at [Stamp.opacity], multiplied with what is beneath
/// (`mix-blend-mode: multiply; opacity: 0.9`).
class _MultiplyLayer extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMultiply();
}

class _RenderMultiply extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    // The outline reaches past the box; the layer must hold it too.
    const outset = Stamp.outlineOffset + Stamp.outlineWidth;
    context.canvas.saveLayer(
      (offset & size).inflate(outset),
      Paint()
        ..blendMode = BlendMode.multiply
        ..color = const Color(0xFF000000).withValues(alpha: Stamp.opacity),
    );
    context.paintChild(child, offset);
    context.canvas.restore();
  }
}
