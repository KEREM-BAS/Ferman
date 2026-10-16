import 'package:ferman/design/icons/icon.dart';

/// The eight modes of the editor, in the drawn order: the design-system
/// constant `FERMAN_MODES` (`components/navigation/ModeTabs.jsx`) as
/// `FmWindow` draws it (`MODE_IDS` and `MODE_ICONS`, `FmWindow.dc.html`
/// lines 190–191).
///
/// The bundle's constant lists seven modes; every artboard and the owner
/// add Tools, so the enum has eight (G09, Q05).
///
/// Each mode carries its design [id] and [icon]. Its label is not here:
/// mode names are user-facing copy and come from the ARB files, so the
/// widgets that show a mode (`ModeTabs`) take them from the caller
/// (`labelOf`), usually an exhaustive `switch` over [FermanMode] that
/// returns the localized names. The English labels of the design are View,
/// Edit, Comment, Fill & Sign, Organize, Convert, Protect and Tools; mode
/// names are proper nouns and keep their casing (readme "Casing").
enum FermanMode {
  /// View: reading, zoom and page layout (`book-open`).
  view('view', IconName.bookOpen),

  /// Edit: text and content editing (`file-pen-line`).
  edit('edit', IconName.filePenLine),

  /// Comment: annotations and notes (`message-square`).
  comment('comment', IconName.messageSquare),

  /// Fill & Sign: forms and signatures (`signature`).
  sign('sign', IconName.signature),

  /// Organize: pages (`layout-grid`).
  organize('organize', IconName.layoutGrid),

  /// Convert: export and import (`refresh-cw`).
  convert('convert', IconName.refreshCw),

  /// Protect: passwords, redaction and certificates (`shield`).
  protect('protect', IconName.shield),

  /// Tools: compress, compare, accessibility and the other tools
  /// (`wrench`; G09).
  tools('tools', IconName.wrench);

  new(this.id, this.icon);

  /// The design's id (`MODE_IDS`), stable across languages.
  final String id;

  /// The glyph shown before the label when icons are on (`MODE_ICONS`).
  final IconName icon;
}
