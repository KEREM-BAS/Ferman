import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// One reply under a note or a comment, the design-system `NoteReply`
/// (`StickyNote.jsx`; `CommentCard` uses the same shape).
@immutable
class NoteReply {
  /// A reply by [author] at [time] saying [text].
  const new({required this.author, required this.time, required this.text});

  /// Who replied.
  final String author;

  /// When, already formatted from the region setting by the caller.
  final String time;

  /// The reply.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is NoteReply &&
      other.author == author &&
      other.time == time &&
      other.text == text;

  @override
  int get hashCode => Object.hash(author, time, text);

  @override
  String toString() => 'NoteReply($author, $time)';
}

/// A note annotation, the design-system `StickyNote` component
/// (`components/annotations/annotations.css`, `.fm-note-pin`, `.fm-note`;
/// `StickyNote.jsx`): a collapsed pin on the page, or an expanded card with
/// the note, its replies and a reply field.
///
/// **Collapsed** ([collapsed]): a 24 px pin in the annotation [color] with
/// 4 px corners, a hairline and a small shadow, showing a 14 px
/// `message-square` in page ink. Activating it (click, Enter, Space) calls
/// [onToggle]. Its keyboard focus is a page-tuned ring: 2 px white, then
/// 2 px ink 500 (`.fm-note-pin:focus-visible`), its corners growing with
/// each band as CSS spread shadows do.
///
/// **Expanded**: a 256 px card on the raised surface with medium corners
/// and the popover shadow. Its 32 px head is in [color] with [author]
/// (semibold, ellipsized), [time] and two 22 px icon buttons in page ink:
/// More ([onMore]; disabled with "Available in a future version" until the
/// note menu arrives) and Close ([onToggle]). Then [text] (body type,
/// keeping its line breaks), each of [replies] over a hairline (author in
/// semibold with the time after it), [child], and, while [onReply] is set,
/// a small reply field (Enter sends a non-empty reply through [onReply]
/// and clears the field, which keeps focus for the next reply).
///
/// **Keyboard** (board `a4-1d`): opening the note from the keyboard moves
/// focus into the card; Tab moves through More, Close and the reply field
/// and on out of the card. Escape anywhere in the card calls [onToggle]
/// (close), and closing from the keyboard (Escape, or Close activated
/// while focus is in the card) returns focus to the pin.
///
/// The head, pin and note colours are document colours; the card surface,
/// text and field follow the theme. The bundle's English names
/// (`Note from <author>`, "More", "Close note", "Reply") come from the caller:
/// [semanticLabel], [moreLabel], [closeLabel] and [replyPlaceholder].
///
/// For screen readers the pin is a button and the card a dialog, both named
/// [semanticLabel].
class StickyNote extends StatefulWidget {
  /// Creates a note by [author] at [time] saying [text].
  const new({
    required this.author,
    required this.time,
    required this.text,
    required this.semanticLabel,
    required this.moreLabel,
    required this.closeLabel,
    super.key,
    this.collapsed = false,
    this.color = AnnotationColor.yellow,
    this.replies = const [],
    this.onToggle,
    this.onReply,
    this.onMore,
    this.replyPlaceholder,
    this.child,
  });

  /// `.fm-note-pin` `width` and `height: 24px`.
  static const double pinSize = 24;

  /// `.fm-note-pin` `border-radius: 4px`.
  static const double pinRadius = 4;

  /// `StickyNote.jsx` pin and head icon size.
  static const double iconSize = 14;

  /// `.fm-note-pin` `box-shadow: 0 0 0 1px rgba(0,0,0,.12), …`: the
  /// hairline ring at rest, painted with its corner grown to 5 px as CSS
  /// does.
  static const List<BoxShadow> pinRing = [
    BoxShadow(color: Color(0x1F000000), spreadRadius: 1),
  ];

  /// `.fm-note-pin` `box-shadow: …, 0 2px 4px rgba(0,0,0,.14)`: the drop
  /// shadow at rest.
  static const List<BoxShadow> pinDropShadow = [
    BoxShadow(color: Color(0x24000000), offset: Offset(0, 2), blurRadius: 4),
  ];

  /// `.fm-note-pin:focus-visible` `box-shadow: 0 0 0 2px #FFFFFF,
  /// 0 0 0 4px var(--ink-500)`: the page-tuned focus ring, inner part.
  static const Color pinFocusGap = Color(0xFFFFFFFF);

  /// That ring's `0 0 0 2px`: the white band's spread.
  static const double pinFocusGapSpread = 2;

  /// That ring's `0 0 0 4px`: the ink band's spread.
  static const double pinFocusSpread = 4;

  /// `.fm-note` `width: 256px`.
  static const double cardWidth = 256;

  /// `.fm-note__head` `height: 32px`.
  static const double headHeight = 32;

  /// `.fm-note__head .fm-iconbtn:hover` `background: rgba(0,0,0,.08)`.
  static const Color headButtonHover = Color(0x14000000);

  /// The head buttons' fill at rest: [headButtonHover] fully transparent,
  /// so the hover tint fades in from nothing.
  static const Color headButtonRest = Color(0x00000000);

  /// Whether the note shows as a pin.
  final bool collapsed;

  /// The annotation colour of the pin and the card's head.
  final AnnotationColor color;

  /// Who wrote the note.
  final String author;

  /// When, already formatted from the region setting by the caller.
  final String time;

  /// The note.
  final String text;

  /// The replies, oldest first.
  final List<NoteReply> replies;

  /// Called when the pin is activated or the card's Close is pressed.
  final VoidCallback? onToggle;

  /// Called with a reply sent from the reply field; null hides the field.
  final ValueChanged<String>? onReply;

  /// Called when the card's More button is pressed; null disables it with
  /// "Available in a future version". Not a design-system prop.
  final VoidCallback? onMore;

  /// The accessible name of the pin and the card, the localized
  /// `Note from <author>`. Not a design-system prop.
  final String semanticLabel;

  /// The name and tooltip of the More button, the localized "More". Not a
  /// design-system prop.
  final String moreLabel;

  /// The name and tooltip of the Close button, the localized "Close note".
  /// Not a design-system prop.
  final String closeLabel;

  /// The reply field's placeholder and name, the localized "Reply"; null
  /// shows none. Not a design-system prop.
  final String? replyPlaceholder;

  /// Extra content under the replies.
  final Widget? child;

  @override
  State<StickyNote> createState() => _StickyNoteState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('collapsed', value: collapsed, ifTrue: 'collapsed'))
      ..add(
        EnumProperty<AnnotationColor>(
          'color',
          color,
          defaultValue: AnnotationColor.yellow,
        ),
      )
      ..add(StringProperty('author', author))
      ..add(StringProperty('time', time))
      ..add(IntProperty('replies', replies.length))
      ..add(StringProperty('semanticLabel', semanticLabel));
  }
}

class _StickyNoteState extends State<StickyNote> {
  final TextEditingController _reply = TextEditingController();
  final FocusNode _pinNode = FocusNode(debugLabel: 'StickyNote.pin');
  final FocusNode _replyNode = FocusNode(debugLabel: 'StickyNote.reply');

  /// The card's focus scope: Escape inside it closes the note. A note on
  /// the page is not modal, so Tab leaves it at either end.
  final FocusScopeNode _cardNode = FocusScopeNode(
    debugLabel: 'StickyNote.card',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  @override
  void didUpdateWidget(StickyNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The old subtree is still mounted here, so `hasFocus` is current.
    final closing = !oldWidget.collapsed && widget.collapsed;
    final opening = oldWidget.collapsed && !widget.collapsed;
    if ((closing && _cardNode.hasFocus) || (opening && _pinNode.hasFocus)) {
      // Closed from the keyboard, focus returns to the pin (a4-1d); opened
      // from it, focus moves into the note. After this frame, once the
      // new side is in the focus tree: a scope that is not attached yet
      // drops a focus request.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.collapsed != closing) return;
        (closing ? _pinNode : _cardNode).requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    _pinNode.dispose();
    _replyNode.dispose();
    _cardNode.dispose();
    super.dispose();
  }

  void _send(String value) {
    // The field keeps focus for the next reply, as the bundle's input does
    // (Enter would otherwise give it up; both land in one focus update).
    _replyNode.requestFocus();
    final onReply = widget.onReply;
    if (onReply == null || value.isEmpty) return;
    onReply(value);
    _reply.clear();
  }

  KeyEventResult _onCardKey(FocusNode _, KeyEvent event) {
    final onToggle = widget.onToggle;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        onToggle != null) {
      onToggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) =>
      widget.collapsed ? _pin(context) : _card(context);

  Widget _pin(BuildContext context) {
    final theme = context.ferman;
    final ramps = theme.ramps;
    final fill = widget.color.resolve(theme);
    const radius = BorderRadius.all(Radius.circular(StickyNote.pinRadius));
    return FermanInteractive(
      focusNode: _pinNode,
      onPressed: widget.onToggle,
      semanticLabel: widget.semanticLabel,
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        // The spread rings round out with each band (radius 5, or 6 and 8
        // for the focus ring), as CSS spread shadows do, and sit above the
        // drop shadow. Focus replaces the whole box shadow.
        return CustomPaint(
          foregroundPainter: FocusRingPainter(
            layers: focused
                ? [
                    BoxShadow(
                      color: ramps.ink500,
                      spreadRadius: StickyNote.pinFocusSpread,
                    ),
                    const BoxShadow(
                      color: StickyNote.pinFocusGap,
                      spreadRadius: StickyNote.pinFocusGapSpread,
                    ),
                  ]
                : StickyNote.pinRing,
            borderRadius: radius,
          ),
          child: Container(
            key: const ValueKey<String>('StickyNote.pin'),
            width: StickyNote.pinSize,
            height: StickyNote.pinSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              boxShadow: focused ? null : StickyNote.pinDropShadow,
            ),
            child: Icon(
              IconName.messageSquare,
              size: StickyNote.iconSize,
              color: ramps.paper900,
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final ramps = theme.ramps;
    final type = theme.typography;
    final scale = theme.typeScale;
    final hairline = BorderDirectional(
      top: BorderSide(
        color: colors.borderSubtle,
        width: theme.border.borderWidth,
      ),
    );
    final timeStyle = type.body.copyWith(
      fontSize: scale.sizeXs,
      height: 1,
      color: ramps.paper700,
      fontFeatures: scale.numericTabular,
    );
    final onMore = widget.onMore;
    final head = Container(
      key: const ValueKey<String>('StickyNote.head'),
      height: StickyNote.headHeight,
      color: widget.color.resolve(theme),
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space2_5,
        end: theme.space.space1,
      ),
      child: Row(
        spacing: theme.space.space2,
        children: [
          Expanded(
            child: Text(
              widget.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: type.body.copyWith(
                fontSize: scale.sizeSm,
                height: 1,
                fontWeight: scale.weightSemibold,
                color: ramps.paper900,
              ),
            ),
          ),
          Text(widget.time, style: timeStyle),
          _HeadButton(
            icon: IconName.ellipsis,
            label: widget.moreLabel,
            onPressed: onMore,
            disabledReason: onMore == null
                ? futureVersionReason(context)
                : null,
          ),
          _HeadButton(
            icon: IconName.x,
            label: widget.closeLabel,
            onPressed: widget.onToggle,
          ),
        ],
      ),
    );
    final body = Padding(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: theme.space.space2_5,
        horizontal: theme.space.space3,
      ),
      child: Text(widget.text, style: type.body),
    );
    final replies = [
      for (final reply in widget.replies)
        Container(
          decoration: BoxDecoration(border: hairline),
          padding: EdgeInsetsDirectional.symmetric(
            vertical: theme.space.space2,
            horizontal: theme.space.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space0_5,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: reply.author),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: reply.time,
                      style: timeStyle.copyWith(
                        fontWeight: scale.weightRegular,
                      ),
                    ),
                  ],
                ),
                style: type.body.copyWith(
                  fontSize: scale.sizeSm,
                  height: scale.heightSm,
                  fontWeight: scale.weightSemibold,
                ),
              ),
              Text(reply.text, style: type.body),
            ],
          ),
        ),
    ];
    final child = widget.child;
    final foot = widget.onReply == null
        ? null
        : Container(
            decoration: BoxDecoration(border: hairline),
            padding: EdgeInsetsDirectional.fromSTEB(
              theme.space.space2_5,
              theme.space.space2,
              theme.space.space2_5,
              theme.space.space2_5,
            ),
            child: TextField(
              size: FieldSize.sm,
              controller: _reply,
              focusNode: _replyNode,
              placeholder: widget.replyPlaceholder,
              semanticLabel: widget.replyPlaceholder,
              onSubmitted: _send,
            ),
          );
    final card = Container(
      key: const ValueKey<String>('StickyNote.card'),
      width: StickyNote.cardWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
        boxShadow: theme.elevation.shadowPopover,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.textPrimary),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [head, body, ...replies, ?child, ?foot],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      scopesRoute: true,
      namesRoute: true,
      label: widget.semanticLabel,
      child: FocusScope(
        node: _cardNode,
        includeSemantics: false,
        onKeyEvent: _onCardKey,
        child: card,
      ),
    );
  }
}

/// A 22 px icon button on the coloured head (`.fm-iconbtn--xs` inside
/// `.fm-note__head`): page ink, with the head's own hover tint.
class _HeadButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabledReason,
  });

  final IconName icon;
  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusXs));
    return FermanInteractive(
      onPressed: onPressed,
      disabledReason: disabledReason,
      tooltip: label,
      semanticLabel: label,
      builder: (context, states, _) {
        final disabled = states.contains(WidgetState.disabled);
        final tinted =
            !disabled &&
            (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed));
        final size = theme.density.controlHXs;
        final motion = theme.motion;
        // `.fm-iconbtn` transitions: the focus ring over --dur-fast, the
        // tint and the icon colour over --dur-instant (none under reduced
        // motion).
        return FocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          duration: motion.durFast,
          curve: motion.easeOut,
          child: AnimatedContainer(
            duration: motion.durInstant,
            curve: motion.easeOut,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tinted
                  ? StickyNote.headButtonHover
                  : StickyNote.headButtonRest,
              borderRadius: radius,
            ),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: disabled ? theme.ramps.paper500 : theme.ramps.paper800,
              ),
              duration: motion.durInstant,
              curve: motion.easeOut,
              builder: (context, color, _) =>
                  Icon(icon, size: StickyNote.iconSize, color: color),
            ),
          ),
        );
      },
    );
  }
}
