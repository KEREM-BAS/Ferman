import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a text fails to fit its box.
enum TextFitKind {
  /// More lines than `maxLines`: the rest is cut off, with an ellipsis
  /// when the text asks for one.
  truncated,

  /// Wider than its box on one line (`softWrap: false` or one line), or
  /// with a word wider than its box: clipped, faded or painted outside.
  tooWide,

  /// Taller than its box: the box's height is fixed below the text's.
  tooTall,

  /// Painted outside the window.
  outsideView,
}

/// A text on screen that does not fit, found by [textFitProblems].
final class TextFitProblem {
  /// The problem of the text [text] of the [widget] at [rect].
  const new({
    required this.text,
    required this.kind,
    required this.needed,
    required this.available,
    required this.rect,
    required this.widget,
  });

  /// The text's plain characters.
  final String text;

  /// How it does not fit.
  final TextFitKind kind;

  /// The width or height the whole text needs, in logical pixels (for
  /// [TextFitKind.truncated] the height of every line).
  final double needed;

  /// The width or height it has.
  final double available;

  /// Where the text is, in global coordinates.
  final Rect rect;

  /// The widgets above the text, nearest first, without the plain layout
  /// ones: the control and the screen part it sits in.
  final String widget;

  /// How many pixels are missing.
  double get missing => needed - available;

  @override
  String toString() =>
      '${kind.name} by ${missing.toStringAsFixed(1)} px '
      '(needs ${needed.toStringAsFixed(1)}, has '
      '${available.toStringAsFixed(1)}) in $widget at '
      '${rect.left.toStringAsFixed(0)},${rect.top.toStringAsFixed(0)}: '
      '"$text"';
}

/// Plain layout widgets, left out of a problem's [TextFitProblem.widget].
const Set<Type> _textWrappers = {
  RichText,
  Text,
  DefaultTextStyle,
  ExcludeSemantics,
  MergeSemantics,
  Semantics,
  Padding,
  Expanded,
  Flexible,
  Align,
  Center,
  SizedBox,
  ConstrainedBox,
  KeyedSubtree,
  Row,
  Column,
  Flex,
  Wrap,
  Container,
  DecoratedBox,
  ColoredBox,
  IntrinsicHeight,
  Stack,
  Focus,
  FocusableActionDetector,
  Actions,
  Shortcuts,
  MouseRegion,
  Listener,
  GestureDetector,
  RawGestureDetector,
  OverlayPortal,
  Builder,
  LayoutBuilder,
};

/// The framework's own private plumbing, left out like [_textWrappers].
final RegExp _privatePlumbing = RegExp(
  '^_(Focus|Overlay|Actions|Shortcuts|Gesture|Mouse|Semantics|Raw|Inherited)',
);

/// Every text on screen (each onstage [RichText], which [Text] builds) that
/// does not fit its box: cut off after `maxLines`, wider or taller than its
/// box, or outside the window.
///
/// A text inside a widget for which [allowed] returns true is left out:
/// controls whose design truncates too (a native `<select>` or `<input>`
/// is one line and clips its text).
///
/// [tolerance] absorbs sub-pixel rounding.
List<TextFitProblem> textFitProblems(
  WidgetTester tester, {
  bool Function(Element text)? allowed,
  double tolerance = 0.5,
}) {
  final view = tester.view;
  final viewSize = view.physicalSize / view.devicePixelRatio;
  final problems = <TextFitProblem>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    if (!paragraph.attached) continue;
    if (allowed?.call(element) ?? false) continue;
    final size = paragraph.size;
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    if (text.trim().isEmpty) continue;
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & size,
    );
    final owner = _ownerOf(element);
    TextFitProblem problem(TextFitKind kind, double needed, double available) =>
        TextFitProblem(
          text: text,
          kind: kind,
          needed: needed,
          available: available,
          rect: rect,
          widget: owner,
        );

    TextPainter painter({int? maxLines}) => TextPainter(
      text: paragraph.text,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: maxLines,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    );

    // The whole text on one line, and its longest unbreakable run.
    final free = painter()..layout();
    final oneLine = !paragraph.softWrap || paragraph.maxLines == 1;
    final neededWidth = oneLine
        ? free.maxIntrinsicWidth
        : free.minIntrinsicWidth;
    // Every line at the box's width, without a line limit.
    final wrapped = painter()..layout(maxWidth: size.width);
    final limited = painter(maxLines: paragraph.maxLines)
      ..layout(maxWidth: size.width);
    try {
      if (paragraph.didExceedMaxLines || limited.didExceedMaxLines) {
        problems.add(
          oneLine
              ? problem(TextFitKind.truncated, neededWidth, size.width)
              : problem(TextFitKind.truncated, wrapped.height, size.height),
        );
      } else if (neededWidth > size.width + tolerance) {
        problems.add(problem(TextFitKind.tooWide, neededWidth, size.width));
      } else if (limited.height > size.height + tolerance) {
        problems.add(problem(TextFitKind.tooTall, limited.height, size.height));
      } else if (rect.left < -tolerance ||
          rect.right > viewSize.width + tolerance) {
        problems.add(
          problem(
            TextFitKind.outsideView,
            rect.right > viewSize.width ? rect.right : -rect.left,
            viewSize.width,
          ),
        );
      }
    } finally {
      free.dispose();
      wrapped.dispose();
      limited.dispose();
    }
  }
  return problems;
}

String _ownerOf(Element element) {
  final names = <String>[];
  element.visitAncestorElements((ancestor) {
    final type = ancestor.widget.runtimeType;
    final name = type.toString();
    if (!_textWrappers.contains(type) && !_privatePlumbing.hasMatch(name)) {
      names.add(name);
    }
    return names.length < 4;
  });
  return names.join(' ‹ ');
}

/// Whether [element] is inside a widget of a type for which [test] returns
/// true.
bool hasAncestor(Element element, bool Function(Widget widget) test) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    found = test(ancestor.widget);
    return !found;
  });
  return found;
}

/// Runs [body] while collecting every error the framework reports, such as
/// a RenderFlex overflow, instead of failing the test at the first one, and
/// returns them; the test's own error handler is back afterwards.
Future<List<FlutterErrorDetails>> collectFlutterErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// The first line of each of [errors]: "A RenderFlex overflowed by 12
/// pixels on the right." and the like.
List<String> describeErrors(List<FlutterErrorDetails> errors) => [
  for (final error in errors)
    error.exceptionAsString().split('\n').first.trim(),
];
