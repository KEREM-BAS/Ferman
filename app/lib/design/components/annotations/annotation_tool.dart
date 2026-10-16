import 'package:ferman/design/icons/icon.dart';
import 'package:flutter/services.dart';

/// The comment tools in the drawn order: the design-system constant
/// `ANNOTATION_TOOLS` (`components/annotations/AnnotationTools.jsx`) as
/// `FmWindow` draws it (`annotTools`, `FmWindow.dc.html` lines 233–237,
/// and board a4-1).
///
/// The bundle's constant has nine tools, labels the text tool "Text box"
/// and draws Shapes with the `square` icon; every board draws eleven,
/// adding Callout and Measure, so the enum follows the drawing (G62), as
/// `FermanMode` does for the mode tabs (G09).
///
/// Each tool carries its design [id], [icon], single-key [shortcut], whether
/// it draws in the annotation colour ([colored]) and whether it opens a
/// menu ([hasMenu]). Its label is user-facing copy and comes from the ARB
/// files, so `AnnotationTools` takes the labels from the caller
/// (`toolLabelOf`). The English labels of the design are Select, Highlight,
/// Underline, Strikethrough, Note, Text, Callout, Draw, Shapes, Stamp and
/// Measure.
enum AnnotationTool {
  /// Select (`mouse-pointer-2`), key V.
  select('select', IconName.mousePointer2, shortcut: 'V'),

  /// Highlight (`highlighter`), key H, coloured.
  highlight('highlight', IconName.highlighter, shortcut: 'H', colored: true),

  /// Underline (`underline`), key U, coloured.
  underline('underline', IconName.underline, shortcut: 'U', colored: true),

  /// Strikethrough (`strikethrough`), key S, coloured.
  strikethrough(
    'strikethrough',
    IconName.strikethrough,
    shortcut: 'S',
    colored: true,
  ),

  /// Note (`sticky-note`), key N, coloured.
  note('note', IconName.stickyNote, shortcut: 'N', colored: true),

  /// Text (`type`), key X; the bundle's "Text box".
  text('text', IconName.type, shortcut: 'X'),

  /// Callout (`message-square`), key C; drawn, not in the bundle.
  callout('callout', IconName.messageSquare, shortcut: 'C'),

  /// Draw (`pen-tool`), key P, coloured.
  pen('pen', IconName.penTool, shortcut: 'P', colored: true),

  /// Shapes (`shapes`), key R, coloured, with a menu.
  shapes(
    'shapes',
    IconName.shapes,
    shortcut: 'R',
    colored: true,
    hasMenu: true,
  ),

  /// Stamp (`stamp`), with a menu; no shortcut.
  stamp('stamp', IconName.stamp, hasMenu: true),

  /// Measure (`ruler`), key M, with a menu; drawn, not in the bundle.
  measure('measure', IconName.ruler, shortcut: 'M', hasMenu: true);

  new(
    this.id,
    this.icon, {
    this.shortcut,
    this.colored = false,
    this.hasMenu = false,
  });

  /// The design's id, stable across languages.
  final String id;

  /// The glyph of the tool button.
  final IconName icon;

  /// The single-key shortcut from the shortcut table, as its key cap (the
  /// design's `key`); null when the tool has none. Shown in the tooltip.
  final String? shortcut;

  /// Whether the tool draws in the annotation colour: the tool button then
  /// shows a swatch of it, and the colour group is enabled.
  final bool colored;

  /// Whether the tool opens a menu (the design's `menu`): shapes, stamps,
  /// measurements.
  final bool hasMenu;

  /// The key that selects the tool ([shortcut]); null when it has none.
  LogicalKeyboardKey? get shortcutKey => switch (this) {
    select => LogicalKeyboardKey.keyV,
    highlight => LogicalKeyboardKey.keyH,
    underline => LogicalKeyboardKey.keyU,
    strikethrough => LogicalKeyboardKey.keyS,
    note => LogicalKeyboardKey.keyN,
    text => LogicalKeyboardKey.keyX,
    callout => LogicalKeyboardKey.keyC,
    pen => LogicalKeyboardKey.keyP,
    shapes => LogicalKeyboardKey.keyR,
    stamp => null,
    measure => LogicalKeyboardKey.keyM,
  };
}
