import 'package:ferman/design/theme.dart';
import 'package:flutter/painting.dart';

/// The annotation palette (`--annot-*` in `tokens/colors.css`; the bundle's
/// `COLORS` in `Highlight.jsx`).
///
/// The colours are document colours and the same in light and dark: the
/// page stays white. `AnnotationTools` offers yellow, green, blue, pink,
/// red and ink (`AnnotationTools.palette`, the bundle's `PALETTE`);
/// `StickyNote` offers the first five.
///
/// Colour names are user-facing copy and come from the caller
/// (`colorLabelOf`). The design's English names are Yellow, Green, Blue,
/// Pink, Orange, Red and Black (for [ink]).
enum AnnotationColor {
  /// `--annot-yellow`.
  yellow,

  /// `--annot-green`.
  green,

  /// `--annot-blue`.
  blue,

  /// `--annot-pink`.
  pink,

  /// `--annot-orange`.
  orange,

  /// `--annot-red`.
  red,

  /// `--annot-ink`, named Black in the design.
  ink;

  /// This colour from [theme]'s annotation palette.
  Color resolve(FermanTheme theme) {
    final ramps = theme.ramps;
    return switch (this) {
      yellow => ramps.annotYellow,
      green => ramps.annotGreen,
      blue => ramps.annotBlue,
      pink => ramps.annotPink,
      orange => ramps.annotOrange,
      red => ramps.annotRed,
      ink => ramps.annotInk,
    };
  }
}
