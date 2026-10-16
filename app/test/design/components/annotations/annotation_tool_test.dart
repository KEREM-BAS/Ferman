import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eleven tools in the FmWindow order (G62)', () {
    expect(
      [for (final tool in AnnotationTool.values) tool.id],
      [
        'select',
        'highlight',
        'underline',
        'strikethrough',
        'note',
        'text',
        'callout',
        'pen',
        'shapes',
        'stamp',
        'measure',
      ],
    );
    expect(
      [for (final tool in AnnotationTool.values) tool.icon],
      [
        IconName.mousePointer2,
        IconName.highlighter,
        IconName.underline,
        IconName.strikethrough,
        IconName.stickyNote,
        IconName.type,
        IconName.messageSquare,
        IconName.penTool,
        IconName.shapes,
        IconName.stamp,
        IconName.ruler,
      ],
    );
  });

  test('single-key shortcuts, colour and menu flags', () {
    expect(
      [for (final tool in AnnotationTool.values) tool.shortcut],
      ['V', 'H', 'U', 'S', 'N', 'X', 'C', 'P', 'R', null, 'M'],
    );
    expect(
      [
        for (final tool in AnnotationTool.values)
          if (tool.colored) tool,
      ],
      [
        AnnotationTool.highlight,
        AnnotationTool.underline,
        AnnotationTool.strikethrough,
        AnnotationTool.note,
        AnnotationTool.pen,
        AnnotationTool.shapes,
      ],
    );
    expect(
      [
        for (final tool in AnnotationTool.values)
          if (tool.hasMenu) tool,
      ],
      [AnnotationTool.shapes, AnnotationTool.stamp, AnnotationTool.measure],
    );
    for (final tool in AnnotationTool.values) {
      final key = tool.shortcutKey;
      expect(key?.keyLabel, tool.shortcut, reason: tool.id);
    }
    expect(AnnotationTool.select.shortcutKey, LogicalKeyboardKey.keyV);
  });

  test('annotation colours resolve to the palette in both themes', () {
    for (final theme in [FermanTheme.light, FermanTheme.dark]) {
      expect(AnnotationColor.yellow.resolve(theme), theme.ramps.annotYellow);
      expect(AnnotationColor.orange.resolve(theme), theme.ramps.annotOrange);
      expect(AnnotationColor.ink.resolve(theme), theme.ramps.annotInk);
    }
  });
}
