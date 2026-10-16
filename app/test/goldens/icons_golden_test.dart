import 'package:alchemist/alchemist.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:flutter/widgets.dart' hide Icon;

import '../helpers/golden_config.dart';

const int _columns = 6;
const double _cellWidth = 168;
const double _cellHeight = 24;
const double _gap = 8;

final Color _iconColor = FermanColorTokens.light.iconPrimary;

final TextStyle _idStyle = TextStyle(
  fontFamily: FermanTypeTokens.fontMono.family,
  fontSize: FermanTypeTokens.size2xs,
  color: FermanColorTokens.light.textSecondary,
);

/// One icon at [size] next to its design-system name.
Widget _cell(IconName name, {double size = Icon.defaultSize}) => SizedBox(
  width: _cellWidth,
  height: _cellHeight,
  child: Row(
    children: [
      Icon(name, size: size, color: _iconColor),
      const SizedBox(width: _gap),
      Flexible(child: Text(name.id, style: _idStyle, softWrap: false)),
    ],
  ),
);

/// [names] in rows of [_columns], in reading order of the ambient
/// direction.
Widget _grid(List<IconName> names) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var start = 0; start < names.length; start += _columns)
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in names.skip(start).take(_columns)) _cell(name),
        ],
      ),
  ],
);

/// The eight directional glyphs, then glyphs that look directional but
/// never mirror (ADR 0013).
const List<IconName> _mirrorCheck = [
  IconName.arrowLeft,
  IconName.arrowRight,
  IconName.chevronLeft,
  IconName.chevronRight,
  IconName.undo2,
  IconName.redo2,
  IconName.skipBack,
  IconName.skipForward,
  IconName.arrowLeftRight,
  IconName.chevronsLeft,
  IconName.chevronsRight,
  IconName.send,
];

Future<void> main() async {
  await goldenTest(
    'all 229 icons draw from the design path data, and directional icons '
    'mirror in right to left',
    skip: !isGoldenHost,
    fileName: 'icons',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name:
              'All ${IconName.values.length} icons, '
              '${Icon.defaultSize.round()} px, stroke '
              '${Icon.defaultStrokeWidth}',
          child: _grid(IconName.values),
        ),
        GoldenTestScenario(name: 'Left to right', child: _grid(_mirrorCheck)),
        GoldenTestScenario(
          name: 'Right to left: the first eight mirror, the last four do not',
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _grid(_mirrorCheck),
          ),
        ),
        GoldenTestScenario(
          name: 'Sizes 12 (stroke 2), 14, 16, 20, 24 and 32 px',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in [IconName.search, IconName.chevronRight]) ...[
                Icon(name, size: 12, strokeWidth: 2, color: _iconColor),
                for (final size in [14.0, 16.0, 20.0, 24.0, 32.0]) ...[
                  const SizedBox(width: _gap),
                  Icon(name, size: size, color: _iconColor),
                ],
                const SizedBox(width: _gap * 3),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
