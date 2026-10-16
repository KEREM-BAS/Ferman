import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The badges a page thumbnail can carry, in the fixed order they stack
/// (`00 Fixes` f5, the `badgeDemo` of `DS additions`).
enum ThumbnailBadge {
  /// Changed since the document was opened: an 8 px accent dot
  /// (`--edit-changed`).
  edited,

  /// Notes or markup on the page: `message-square`.
  comments,

  /// Fields to fill in: `text-cursor-input`.
  formFields,

  /// Signed, or a signature field: `signature`.
  signature,

  /// Missing glyphs, overflow or broken links: an amber `triangle-alert`,
  /// the only coloured chip.
  warnings;

  /// The chip's glyph; null for the [edited] dot.
  IconName? get icon => switch (this) {
    edited => null,
    comments => IconName.messageSquare,
    formFields => IconName.textCursorInput,
    signature => IconName.signature,
    warnings => IconName.triangleAlert,
  };
}

/// The badges stacked at a page thumbnail's top-end corner, a DS addition
/// (`00 Fixes` f5, lines 98 to 114; `DS additions` line 60; `FmSidebar`
/// lines 30 to 39).
///
/// Each badge of [badges] is drawn in the fixed [ThumbnailBadge] order,
/// whatever the set's order, 3 px apart in a 16 px column:
/// [ThumbnailBadge.edited] is an 8 px accent dot with a 2 px page-white
/// ring; the others are 16 px white chips with 2 px corners, a 1 px
/// `--paper-200` ring and a 10 px `--paper-800` glyph at stroke 2, and
/// [ThumbnailBadge.warnings] is amber (`--amber-50`, `--amber-200`,
/// `--amber-700`). The badges sit on the white page preview, so their
/// colours do not change with the theme. The page's placeholder lines step
/// aside for them (`PageThumbnail.badges`).
///
/// Each badge shows its text from [tooltips] (such as "1 warning · Madde 6
/// uses a font without ‘ğ’") on hover and keyboard focus.
///
/// **Keyboard** (f5): the badges are one Tab stop; the arrow keys move
/// between them, wrapping, and each badge announces its tooltip. Focus
/// keeps the badge's ring and adds the focus ring (G22).
///
/// [ThumbnailBadgeLegend] is the "Page badges" legend the Pages header's
/// info button opens.
class ThumbnailBadges extends StatefulWidget {
  /// The badges of [badges], explained by [tooltips].
  const new({super.key, this.badges = const {}, this.tooltips = const {}});

  /// `width:16px` of the badge column.
  static const double columnWidth = 16;

  /// `gap:3px` between badges.
  static const double gap = 3;

  /// The edited dot's `width` and `height: 8px`.
  static const double dotSize = 8;

  /// The edited dot's `margin-block: 2px`.
  static const double dotMargin = 2;

  /// The edited dot's `box-shadow: 0 0 0 2px var(--page-bg)`.
  static const double dotRing = 2;

  /// The chips' glyph `size="{{ 10 }}"`.
  static const double iconSize = 10;

  /// The chips' glyph `stroke-width="{{ 2 }}"`.
  static const double iconStroke = 2;

  /// Which badges the page carries.
  final Set<ThumbnailBadge> badges;

  /// The tooltip and accessible name of each badge; a badge without one
  /// shows no tooltip.
  final Map<ThumbnailBadge, String> tooltips;

  /// [badges] in the fixed order.
  List<ThumbnailBadge> get ordered => [
    for (final badge in ThumbnailBadge.values)
      if (badges.contains(badge)) badge,
  ];

  @override
  State<ThumbnailBadges> createState() => _ThumbnailBadgesState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      IterableProperty<ThumbnailBadge>('badges', ordered, ifEmpty: 'none'),
    );
  }
}

class _ThumbnailBadgesState extends State<ThumbnailBadges> {
  final List<FocusNode> _nodes = [];
  final Set<int> _focusVisible = {};
  int _stop = 0;

  void _syncNodes(int count) {
    while (_nodes.length < count) {
      _nodes.add(FocusNode(debugLabel: 'ThumbnailBadge ${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
    if (_stop >= count) _stop = 0;
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final int delta;
    if (key == LogicalKeyboardKey.arrowDown ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight)) {
      delta = 1;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft)) {
      delta = -1;
    } else {
      return KeyEventResult.ignored;
    }
    final from = _nodes.indexWhere((node) => node.hasFocus);
    if (from < 0) return KeyEventResult.ignored;
    final count = _nodes.length;
    _nodes[((from + delta) % count + count) % count].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = widget.ordered;
    _syncNodes(ordered.length);
    if (ordered.isEmpty) return const SizedBox.shrink();
    final theme = context.ferman;
    final forced = FermanForcedStates.of(context).contains(WidgetState.focused);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: SizedBox(
        width: ThumbnailBadges.columnWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: ThumbnailBadges.gap,
          children: [
            for (var i = 0; i < ordered.length; i++)
              _badge(
                context,
                theme,
                ordered[i],
                i,
                focusVisible: _focusVisible.contains(i) || forced,
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(
    BuildContext context,
    FermanTheme theme,
    ThumbnailBadge badge,
    int index, {
    required bool focusVisible,
  }) {
    final message = widget.tooltips[badge];
    final dot = badge == ThumbnailBadge.edited;
    Widget result = FocusRing(
      visible: focusVisible,
      borderRadius: BorderRadius.all(
        Radius.circular(dot ? theme.radius.radiusFull : theme.radius.radiusXs),
      ),
      child: thumbnailBadgeGlyph(theme, badge, ringed: true),
    );
    if (dot) {
      result = Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: ThumbnailBadges.dotMargin,
        ),
        child: result,
      );
    }
    final node = _nodes[index]..skipTraversal = index != _stop;
    result = FocusableActionDetector(
      focusNode: node,
      includeFocusSemantics: false,
      onFocusChange: (value) {
        if (value) setState(() => _stop = index);
      },
      onShowFocusHighlight: (value) => setState(() {
        value ? _focusVisible.add(index) : _focusVisible.remove(index);
      }),
      child: Semantics(
        container: true,
        image: true,
        focusable: true,
        focused: node.hasFocus,
        label: message,
        onFocus: node.requestFocus,
        child: result,
      ),
    );
    if (message != null) {
      result = Tooltip(
        message: message,
        side: TooltipSide.right,
        excludeFromSemantics: true,
        child: result,
      );
    }
    return KeyedSubtree(key: ValueKey<ThumbnailBadge>(badge), child: result);
  }
}

/// The look of [badge], not interactive: the edited dot (with its page
/// ring when [ringed]) or a chip with its glyph. [ThumbnailBadges] and
/// [ThumbnailBadgeLegend] share it.
Widget thumbnailBadgeGlyph(
  FermanTheme theme,
  ThumbnailBadge badge, {
  bool ringed = false,
}) {
  final ramps = theme.ramps;
  final icon = badge.icon;
  if (icon == null) {
    return Container(
      width: ThumbnailBadges.dotSize,
      height: ThumbnailBadges.dotSize,
      decoration: BoxDecoration(
        color: theme.pageColors.editChanged,
        shape: BoxShape.circle,
        boxShadow: ringed
            ? [
                BoxShadow(
                  color: theme.pageColors.pageBg,
                  spreadRadius: ThumbnailBadges.dotRing,
                ),
              ]
            : null,
      ),
    );
  }
  final warning = badge == ThumbnailBadge.warnings;
  final size = theme.size.thumbBadge;
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: warning ? ramps.amber50 : ramps.paper0,
      borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusXs)),
      boxShadow: [
        BoxShadow(
          color: warning ? ramps.amber200 : ramps.paper200,
          spreadRadius: theme.border.borderWidth,
        ),
      ],
    ),
    child: Icon(
      icon,
      size: ThumbnailBadges.iconSize,
      strokeWidth: ThumbnailBadges.iconStroke,
      color: warning ? ramps.amber700 : ramps.paper800,
    ),
  );
}

/// The name and explanation of one badge in a [ThumbnailBadgeLegend], such
/// as ("Edited", "changed since you opened it").
typedef ThumbnailBadgeLegendEntry = ({String name, String description});

/// The "Page badges" legend, a DS addition (`FmSidebar` lines 38 to 47):
/// the popover the Pages header's info button opens (the
/// [ThumbnailBadges] `legendOpen` state).
///
/// A 236 px raised popover (10 px top, 12 px sides and bottom, medium
/// corners, the popover shadow) with [title] in the panel title type, then
/// one row per badge of [entries], in the fixed badge order: the badge's
/// look in a 16 px column and "**name** · description" in caption type,
/// and [footnote] under a hairline in tertiary caption. The screen anchors
/// it under the info button.
///
/// For screen readers it is a dialog named [title].
class ThumbnailBadgeLegend extends StatelessWidget {
  /// A legend titled [title] explaining [entries].
  const new({
    required this.title,
    required this.entries,
    super.key,
    this.footnote,
  });

  /// The legend's `width: 236px`.
  static const double width = 236;

  /// The legend's `gap: 9px`.
  static const double gap = 9;

  /// The heading, the localized "Page badges".
  final String title;

  /// The explanation of each badge; badges without one are left out.
  final Map<ThumbnailBadge, ThumbnailBadgeLegendEntry> entries;

  /// The note under the rows (how screen readers hear the badges); null
  /// shows none.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final caption = theme.typography.caption;
    final footnote = this.footnote;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: title,
      child: Container(
        width: width,
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.space.space3,
          theme.space.space2_5,
          theme.space.space3,
          theme.space.space3,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            Text(
              title,
              style: theme.typography.panelTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space2,
              children: [
                for (final badge in ThumbnailBadge.values)
                  if (entries[badge] case final entry?)
                    Row(
                      spacing: theme.space.space2_5,
                      children: [
                        SizedBox(
                          width: ThumbnailBadges.columnWidth,
                          child: Center(
                            child: thumbnailBadgeGlyph(theme, badge),
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: entry.name,
                                  style: TextStyle(
                                    fontWeight: theme.typeScale.weightMedium,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                TextSpan(text: ' · ${entry.description}'),
                              ],
                            ),
                            style: caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
            if (footnote != null)
              Container(
                padding: EdgeInsetsDirectional.only(top: theme.space.space2),
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    top: BorderSide(
                      color: colors.borderSubtle,
                      width: theme.border.borderWidth,
                    ),
                  ),
                ),
                child: Text(
                  footnote,
                  style: caption.copyWith(color: colors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('title', title))
      ..add(IterableProperty<ThumbnailBadge>('entries', entries.keys))
      ..add(StringProperty('footnote', footnote, defaultValue: null));
  }
}
