import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';

/// When [annotation] was last changed, as FmComments writes it: the time today,
/// "Yesterday", or the date; empty when the file does not say.
String commentTime(
  AnnotationInfo annotation,
  RegionFormat format,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final at = annotation.created ?? annotation.modified;
  if (at == null) return '';
  final today = now ?? DateTime.now();
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  return switch (days) {
    0 => format.time(at),
    1 => l10n.commentYesterday,
    _ => format.date(at),
  };
}

/// The card's glyph for [kind] (FmComments's `T`).
IconName commentIcon(AnnotationKind kind) => switch (kind) {
  AnnotationKind.highlight => IconName.highlighter,
  AnnotationKind.underline || AnnotationKind.squiggly => IconName.underline,
  AnnotationKind.strikeOut => IconName.strikethrough,
  AnnotationKind.note || AnnotationKind.other => IconName.stickyNote,
  AnnotationKind.freeText => IconName.type,
  AnnotationKind.callout => IconName.messageSquare,
  AnnotationKind.ink => IconName.penTool,
  AnnotationKind.square || AnnotationKind.polygon => IconName.square,
  AnnotationKind.circle => IconName.ellipse,
  AnnotationKind.line => IconName.slash,
  AnnotationKind.stamp => IconName.stamp,
};

/// The names of what the comment tools work with.
extension CommentLabels on AppLocalizations {
  /// The name of [kind].
  String commentKindName(AnnotationKind kind) => switch (kind) {
    AnnotationKind.highlight => commentKindHighlight,
    AnnotationKind.underline => commentKindUnderline,
    AnnotationKind.strikeOut => commentKindStrikeOut,
    AnnotationKind.squiggly => commentKindSquiggly,
    AnnotationKind.note => commentKindNote,
    AnnotationKind.freeText => commentKindFreeText,
    AnnotationKind.callout => commentKindCallout,
    AnnotationKind.ink => commentKindInk,
    AnnotationKind.square => commentKindSquare,
    AnnotationKind.circle => commentKindCircle,
    AnnotationKind.line => commentKindLine,
    AnnotationKind.polygon => commentKindPolygon,
    AnnotationKind.stamp => commentKindStamp,
    AnnotationKind.other => commentKindOther,
  };

  /// The name of [type] in FmComments's filter.
  String commentTypeName(CommentTypeFilter type) => switch (type) {
    CommentTypeFilter.all => commentsTypeOther,
    CommentTypeFilter.notes => commentsTypeNotes,
    CommentTypeFilter.markup => commentsTypeMarkup,
    CommentTypeFilter.drawings => commentsTypeDrawings,
    CommentTypeFilter.stamps => commentsTypeStamps,
  };

  /// The name of [sort] in FmComments's filter.
  String commentSortName(CommentSort sort) => switch (sort) {
    CommentSort.page => commentsSortOther,
    CommentSort.newest => commentsSortNewest,
    CommentSort.author => commentsSortAuthor,
  };

  /// The name of [shape] in a4-1's menu.
  String commentShapeName(ShapeTool shape) => switch (shape) {
    ShapeTool.rectangle => commentShapeOther,
    ShapeTool.ellipse => commentShapeEllipse,
    ShapeTool.arrow => commentShapeArrow,
    ShapeTool.line => commentShapeLine,
    ShapeTool.polygon => commentShapePolygon,
  };
}
