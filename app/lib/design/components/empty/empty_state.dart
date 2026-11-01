import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// Why a list is empty (G29): one component for every empty sidebar tab
/// and search, as `a2-3m` draws it in `FmSidebar.dc.html`. A 40 px sunken
/// tile with [icon], the [title] in strong body type and one line of
/// [body] in caption type, centred at the top of the space it is given.
///
/// An optional [action] sits under the body, as a2-3m's "Recognize text
/// (OCR)" for a search that finds no text to search.
class EmptyState extends StatelessWidget {
  /// An empty state.
  const new({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  /// The tile: `width:40px;height:40px`.
  static const double tileSize = 40;

  /// The icon in the tile: `size 20`.
  static const double iconSize = 20;

  /// `padding:36px 18px 0`.
  static const EdgeInsetsDirectional padding = EdgeInsetsDirectional.fromSTEB(
    18,
    36,
    18,
    0,
  );

  /// The icon in the tile.
  final IconName icon;

  /// What is missing.
  final String title;

  /// One line on why, or what fills the list.
  final String body;

  /// A small button under [body]: `margin-top:4px` on the 8 px gap.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Padding(
      padding: padding,
      child: Column(
        spacing: theme.space.space2,
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colors.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radius.radiusMd),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: theme.colors.iconSecondary,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.typography.bodyStrong.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          if (action case final action?)
            Padding(
              padding: EdgeInsetsDirectional.only(top: theme.space.space1),
              child: action,
            ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('icon', icon))
      ..add(StringProperty('title', title))
      ..add(StringProperty('body', body));
  }
}
