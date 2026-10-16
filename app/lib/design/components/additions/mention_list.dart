import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A person a [MentionList] offers: the initials on the avatar and the
/// name (the spec's `MentionCandidate`).
typedef MentionCandidate = ({String initials, String name});

/// The "@" suggestion list under the comment compose field, drawn in
/// `design/FmComments.dc.html` (lines 31–32; component spec
/// `MentionList`): a heading ("People in this document") and one row per
/// person with an initials avatar and the name.
///
/// The list is its own surface (220 px, 4 px of padding, medium corners,
/// the popover shadow) and opens inside a `Popover` with `surface: false`
/// under the compose field. The heading ([heading]) is label type in the
/// tertiary colour; rows are 30 px with a 20 px sunken avatar
/// (semibold 10 px initials) and the name in body type. The active person
/// ([activeIndex]) has the strong selection tint and primary text; the
/// others secondary text. Moving the pointer over a row reports it through
/// [onActiveIndexChanged]; a click chooses it ([onSelected]).
///
/// **Keyboard.** Focus stays in the compose field, which keeps the field
/// ring. The field's host puts [onKeyEvent] on a `Focus` around the field:
/// ArrowDown and ArrowUp move the active person (stopping at the ends),
/// Enter or Tab insert the mention ([onSelected]), Escape calls
/// [onDismiss].
///
/// Mentions travel with the file; Ferman sends no notifications
/// (FmComments footer).
///
/// For screen readers the list is named by [semanticLabel] ("Mention
/// someone"); rows are buttons named by the person, the active one
/// selected.
class MentionList extends StatelessWidget {
  /// Creates the list of [people].
  const new({
    required this.people,
    super.key,
    this.activeIndex = 0,
    this.onSelected,
    this.onDismiss,
    this.onActiveIndexChanged,
    this.heading,
    this.semanticLabel,
  });

  /// The list's `width`.
  static const double width = 220;

  /// A row's `height`.
  static const double rowHeight = 30;

  /// The avatar's `width` and `height`.
  static const double avatarSize = 20;

  /// The people offered, in order.
  final List<MentionCandidate> people;

  /// The index of the active person.
  final int activeIndex;

  /// Called with the person to mention.
  final ValueChanged<MentionCandidate>? onSelected;

  /// Called on Escape.
  final VoidCallback? onDismiss;

  /// Called with the index of the person the pointer or the arrow keys
  /// make active. Not in the spec.
  final ValueChanged<int>? onActiveIndexChanged;

  /// The heading above the people ("People in this document"); null shows
  /// none. Not in the spec.
  final String? heading;

  /// The accessible name of the list ("Mention someone"). Not in the spec.
  final String? semanticLabel;

  /// The key handler for the compose field's host: ArrowDown and ArrowUp
  /// move the active person, Enter and Tab choose it, Escape dismisses.
  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (people.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final last = people.length - 1;
    if (key == LogicalKeyboardKey.arrowDown) {
      onActiveIndexChanged?.call((activeIndex + 1).clamp(0, last));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      onActiveIndexChanged?.call((activeIndex - 1).clamp(0, last));
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      onSelected?.call(people[activeIndex.clamp(0, last)]);
    } else if (key == LogicalKeyboardKey.escape && onDismiss != null) {
      onDismiss?.call();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final title = heading;
    final label = theme.typography.label;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Container(
        width: width,
        padding: EdgeInsetsDirectional.all(theme.space.space1),
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
          children: [
            if (title != null)
              Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space2,
                  vertical: theme.space.space1,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: label.copyWith(color: colors.textTertiary),
                  ),
                ),
              ),
            for (var i = 0; i < people.length; i++)
              _MentionRow(
                person: people[i],
                active: i == activeIndex,
                onHover: () {
                  if (i != activeIndex) onActiveIndexChanged?.call(i);
                },
                onPressed: () => onSelected?.call(people[i]),
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
      ..add(IterableProperty<MentionCandidate>('people', people))
      ..add(IntProperty('activeIndex', activeIndex, defaultValue: 0))
      ..add(StringProperty('heading', heading, defaultValue: null))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// One person row.
class _MentionRow extends StatelessWidget {
  const new({
    required this.person,
    required this.active,
    required this.onHover,
    required this.onPressed,
  });

  final MentionCandidate person;
  final bool active;
  final VoidCallback onHover;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final body = theme.typography.body;
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: person.name,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: Container(
              height: MentionList.rowHeight,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space2,
              ),
              decoration: BoxDecoration(
                color: active ? colors.surfaceSelectedStrong : null,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusSm),
                ),
              ),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  Container(
                    width: MentionList.avatarSize,
                    height: MentionList.avatarSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.all(
                        Radius.circular(theme.radius.radiusSm),
                      ),
                    ),
                    child: Text(
                      person.initials,
                      style: body.copyWith(
                        fontSize: theme.typeScale.size2xs,
                        fontWeight: theme.typeScale.weightSemibold,
                        height: 1,
                        // The board's initials take the row's colour.
                        color: active
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      person.name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: body.copyWith(
                        color: active
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
