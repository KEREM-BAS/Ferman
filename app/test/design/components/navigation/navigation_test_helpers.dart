import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The debug label of the node with the primary focus.
String? get focusLabel => FocusManager.instance.primaryFocus?.debugLabel;

/// The Tab stops in the order their focus nodes were attached (not
/// geometric traversal order), without the binding's scopes.
List<FocusNode> get tabStopNodes => [
  for (final node in FocusManager.instance.rootScope.traversalDescendants)
    if (node is! FocusScopeNode) node,
];

/// The debug labels of [tabStopNodes].
List<String?> get tabStops => [
  for (final node in tabStopNodes) node.debugLabel,
];

/// Moves focus into the first Tab stop, as the first Tab key press does in
/// the app (`componentHost` has no app-level Tab shortcut).
Future<void> focusFirstTabStop(WidgetTester tester) async {
  tabStopNodes.first.requestFocus();
  await tester.pumpAndSettle();
}

/// Moves focus to the next Tab stop, as the Tab key does in the app.
Future<void> pressTab(WidgetTester tester) async {
  FocusManager.instance.primaryFocus!.nextFocus();
  await tester.pumpAndSettle();
}

/// The colour [text] is painted in.
Color? textColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

/// The text style [text] is painted with.
TextStyle textStyle(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

/// The decoration of the nearest [Container] above [of]: a segment's own,
/// or the one an [AnimatedContainer] builds (its current decoration).
BoxDecoration containerDecoration(WidgetTester tester, Finder of) =>
    tester
            .widget<Container>(
              find.ancestor(of: of, matching: find.byType(Container)).first,
            )
            .decoration!
        as BoxDecoration;

/// Transparent, `background: transparent`.
const Color transparent = Color(0x00000000);
