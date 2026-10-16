import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The debug label of the Tab stop [afterLeadingTabStop] puts before the
/// component.
const String leadingTabStopLabel = 'Leading Tab stop';

/// The debug label of the Tab stop [afterLeadingTabStop] puts after the
/// component.
const String trailingTabStopLabel = 'Trailing Tab stop';

/// [child] between a leading Tab stop that takes focus and a trailing one,
/// under the app's own shortcuts and actions (Tab → NextFocusIntent,
/// Enter and Space → ActivateIntent), which componentHost leaves out.
///
/// The Tab key then moves focus from the leading stop to the first Tab
/// stop of [child], as it does from the control before it in the app
/// (ROADMAP step 7: every interactive component is reachable with Tab),
/// and from the last Tab stop of [child] to the trailing stop. The stops
/// keep 16 px from [child], so a focus rect drawn outside its box (a text
/// block's frame) does not share their row in reading order.
Widget afterLeadingTabStop(Widget child) => Shortcuts(
  shortcuts: WidgetsApp.defaultShortcuts,
  child: Actions(
    actions: WidgetsApp.defaultActions,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const Focus(
          autofocus: true,
          debugLabel: leadingTabStopLabel,
          child: SizedBox(width: 8, height: 8),
        ),
        child,
        const Focus(
          debugLabel: trailingTabStopLabel,
          child: SizedBox(width: 8, height: 8),
        ),
      ],
    ),
  ),
);

/// Whether the primary focus is [component]'s element or inside it.
bool focusIsWithin(Finder component) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final element = component.evaluate().single;
  if (identical(focused, element)) return true;
  var within = false;
  focused.visitAncestorElements((ancestor) {
    within = identical(ancestor, element);
    return !within;
  });
  return within;
}

/// Sends Tab from the leading stop of [afterLeadingTabStop] and expects
/// the primary focus inside [component].
Future<void> expectTabReaches(WidgetTester tester, Finder component) async {
  await tester.pumpAndSettle();
  expect(
    FocusManager.instance.primaryFocus?.debugLabel,
    leadingTabStopLabel,
    reason: 'the leading Tab stop has focus before Tab',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  expect(
    focusIsWithin(component),
    isTrue,
    reason:
        'Tab moves focus into $component, not to '
        '${FocusManager.instance.primaryFocus}',
  );
}

/// Sends Tab from the leading stop of [afterLeadingTabStop] and expects
/// the primary focus to pass over [component] to the trailing stop: a
/// control that is not a Tab stop, such as one disabled without a reason.
Future<void> expectTabSkips(WidgetTester tester, Finder component) async {
  await tester.pumpAndSettle();
  expect(
    FocusManager.instance.primaryFocus?.debugLabel,
    leadingTabStopLabel,
    reason: 'the leading Tab stop has focus before Tab',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  expectFocusAfter(component);
}

/// Expects the primary focus on the trailing stop of [afterLeadingTabStop],
/// past [component]: Tab moved on from its last Tab stop, or over it.
void expectFocusAfter(Finder component) {
  expect(focusIsWithin(component), isFalse);
  expect(
    FocusManager.instance.primaryFocus?.debugLabel,
    trailingTabStopLabel,
    reason:
        'Tab moves focus past $component to the next stop, not to '
        '${FocusManager.instance.primaryFocus}',
  );
}
