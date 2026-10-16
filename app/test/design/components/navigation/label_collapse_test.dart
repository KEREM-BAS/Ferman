import 'package:ferman/design/components/navigation/label_collapse.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  group('CollapsibleLabel', () {
    testWidgets('a hidden label measures again only for changes that affect '
        'its width, not for a colour animation', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const DefaultTextStyle(
            style: TextStyle(fontSize: 13, color: Color(0xFF000000)),
            child: CollapsibleLabel(
              compact: true,
              leading: Icon(IconName.hand),
              hiddenLabel: 'Comment',
              fullPadding: 8,
              gap: 6,
            ),
          ),
        ),
      );
      final label = tester.renderObject<RenderCollapsibleLabel>(
        find.byType(CollapsibleLabel),
      );
      final full = label.getMaxIntrinsicWidth(30);
      expect(label.debugNeedsLayout, isFalse);

      // A colour step of a hover animation.
      label.hiddenLabel = const TextSpan(
        text: 'Comment',
        style: TextStyle(fontSize: 13, color: Color(0xFF336699)),
      );
      expect(label.debugNeedsLayout, isFalse);
      expect(label.hiddenLabel?.style?.color, const Color(0xFF336699));
      expect(label.getMaxIntrinsicWidth(30), full);

      // A larger font measures again.
      label.hiddenLabel = const TextSpan(
        text: 'Comment',
        style: TextStyle(fontSize: 20, color: Color(0xFF336699)),
      );
      expect(label.debugNeedsLayout, isTrue);
      await tester.pump();
      expect(label.getMaxIntrinsicWidth(30), greaterThan(full));
    });

    testWidgets('full width and compact width are its intrinsic widths', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const DefaultTextStyle(
            style: TextStyle(fontSize: 13),
            child: CollapsibleLabel(
              leading: SizedBox(width: 16, height: 16),
              label: SizedBox(width: 50, height: 16),
              fullPadding: 8,
              gap: 6,
            ),
          ),
        ),
      );
      final label = tester.renderObject<RenderCollapsibleLabel>(
        find.byType(CollapsibleLabel),
      );
      expect(label.getMaxIntrinsicWidth(30), 8 + 16 + 6 + 50 + 8);
      expect(label.getMinIntrinsicWidth(30), 16);
      expect(label.isCompact, isFalse);
    });
  });
}
