import 'package:ferman/design/components/annotations/sticky_note.dart';
import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A comment in the Comments panel list, a DS addition drawn inline in
/// `FmComments.dc.html` (lines 25 to 35, the card styles on line 76).
///
/// A raised card (9 px by 10 px padding, medium corners, a subtle hairline)
/// stacking, 6 px apart:
///
/// - a head row: a 20 px chip in [chipColor] with the annotation type's
///   [icon] (12 px, stroke 2, [iconColor] or page ink), [author] in body
///   strong (ellipsized), [time] in tertiary caption, and a green
///   `circle-check` when resolved;
/// - [quote], the annotated text, in the document face (12/16 IBM Plex
///   Serif), one ellipsized line;
/// - [text], the comment, when there is one;
/// - when [expanded], the [replies] over a hairline, indented; otherwise
///   [repliesLabel] (such as "2 replies") in accent caption;
/// - while [composing] (expanded only), a small reply field and the Resolve
///   (ghost, check) and Reply (primary) buttons at the end;
/// - when resolved ([resolvedBy], such as "Resolved by Mert Kaya · 11:06"),
///   a footer with that text and a ghost Reopen button.
///
/// States: [expanded] turns the hairline and a 1 px ring the accent colour;
/// resolved fades the card to 78 %; keyboard focus shows the focus ring
/// around the card (G22; not drawn).
///
/// The quotation marks are the locale's, so [quote] comes with them (the
/// board's “…”). Mentions in replies are not highlighted: [NoteReply] has
/// no mention field yet.
///
/// **Keyboard.** The card is a button: Enter and Space call [onPressed]
/// (expand and select the annotation). ArrowUp and ArrowDown move to the
/// card above or below (not drawn). The reply field and the buttons are
/// separate Tab stops; Enter in the field or the Reply button sends a
/// non-empty reply through [onReply] and clears the field.
///
/// For screen readers the card is a button named [semanticLabel] (the
/// board's `<author>, <type> on page N, resolved, N replies`, localized by
/// the screen).
class CommentCard extends StatefulWidget {
  /// A comment by [author] at [time] on [quote].
  const new({
    required this.icon,
    required this.chipColor,
    required this.author,
    required this.time,
    required this.quote,
    required this.semanticLabel,
    required this.resolveLabel,
    required this.replyLabel,
    required this.reopenLabel,
    super.key,
    this.text,
    this.replies = const [],
    this.expanded = false,
    this.composing = false,
    this.resolvedBy,
    this.onPressed,
    this.onResolve,
    this.onReply,
    this.onReopen,
    this.iconColor,
    this.repliesLabel,
    this.replyPlaceholder,
  });

  /// The chip's `width` and `height: 20px`.
  static const double chipSize = 20;

  /// The chip icon's `size="{{ 12 }}"`.
  static const double chipIconSize = 12;

  /// The chip icon's `stroke-width="{{ 2 }}"`.
  static const double chipIconStroke = 2;

  /// The resolved `circle-check`'s `size="{{ 14 }}"`.
  static const double resolvedIconSize = 14;

  /// The card's `padding: 9px 10px`, top and bottom.
  static const double paddingY = 9;

  /// The quote's `font: 400 12px/16px var(--font-doc-sample)`.
  static const double quoteFontSize = 12;

  /// The quote's line height.
  static const double quoteLineHeight = 16;

  /// `op: resolved ? '0.78' : '1'`.
  static const double resolvedOpacity = 0.78;

  /// The annotation type's glyph: highlighter, sticky-note, square,
  /// pen-tool, underline, stamp, strikethrough or type.
  final IconName icon;

  /// The chip's fill (the board's `CHIP`: the annotation colour, or a tint
  /// of it).
  final Color chipColor;

  /// The chip icon's colour; null takes page ink (`#1F1D1A`). The board
  /// colours red and seal icons (`ICOL`). Not in the spec.
  final Color? iconColor;

  /// Who wrote the comment.
  final String author;

  /// When, already formatted from the region setting.
  final String time;

  /// The annotated text, with the locale's quotation marks.
  final String quote;

  /// The comment; null shows none (a drawing without a note).
  final String? text;

  /// The replies, oldest first.
  final List<NoteReply> replies;

  /// Whether the card is the expanded one: accent frame, replies shown.
  final bool expanded;

  /// Whether the reply field and buttons show (expanded cards only).
  final bool composing;

  /// The resolved footer text; null for an open comment.
  final String? resolvedBy;

  /// Called when the card is activated (expand and select).
  final VoidCallback? onPressed;

  /// Called when Resolve is pressed; null disables it.
  final VoidCallback? onResolve;

  /// Called with a reply to send; null disables Reply.
  final ValueChanged<String>? onReply;

  /// Called when Reopen is pressed; null disables it.
  final VoidCallback? onReopen;

  /// The collapsed replies count, such as "2 replies"; null shows none.
  /// Not in the spec.
  final String? repliesLabel;

  /// The accessible name of the card. Not in the spec.
  final String semanticLabel;

  /// The Resolve button's label. Not in the spec.
  final String resolveLabel;

  /// The Reply button's label. Not in the spec.
  final String replyLabel;

  /// The Reopen button's label. Not in the spec.
  final String reopenLabel;

  /// The reply field's placeholder and name; null shows none. Not in the
  /// spec.
  final String? replyPlaceholder;

  /// Whether the comment is resolved.
  bool get resolved => resolvedBy != null;

  @override
  State<CommentCard> createState() => _CommentCardState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<IconName>('icon', icon))
      ..add(ColorProperty('chipColor', chipColor))
      ..add(StringProperty('author', author))
      ..add(StringProperty('time', time))
      ..add(IntProperty('replies', replies.length))
      ..add(FlagProperty('expanded', value: expanded, ifTrue: 'expanded'))
      ..add(FlagProperty('composing', value: composing, ifTrue: 'composing'))
      ..add(StringProperty('resolvedBy', resolvedBy, defaultValue: null))
      ..add(StringProperty('semanticLabel', semanticLabel));
  }
}

/// The focus node of a card, so the arrow keys find the other cards.
class _CommentCardNode extends FocusNode {
  new() : super(debugLabel: 'CommentCard');
}

class _CommentCardState extends State<CommentCard> {
  final _CommentCardNode _node = _CommentCardNode();
  final TextEditingController _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reply.addListener(_onReplyText);
  }

  @override
  void dispose() {
    _reply
      ..removeListener(_onReplyText)
      ..dispose();
    _node.dispose();
    super.dispose();
  }

  bool _hasReply = false;

  void _onReplyText() {
    final has = _reply.text.trim().isNotEmpty;
    if (has != _hasReply) setState(() => _hasReply = has);
  }

  void _send([String? _]) {
    final onReply = widget.onReply;
    final text = _reply.text;
    if (onReply == null || text.trim().isEmpty) return;
    onReply(text);
    _reply.clear();
  }

  /// ArrowUp and ArrowDown: the nearest card above or below.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final down = key == LogicalKeyboardKey.arrowDown;
    if (!down && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final here = _node.rect.center;
    _CommentCardNode? target;
    var best = double.infinity;
    for (final other
        in _node.nearestScope?.traversalDescendants
                .whereType<_CommentCardNode>() ??
            const <_CommentCardNode>[]) {
      if (identical(other, _node)) continue;
      final dy = other.rect.center.dy - here.dy;
      if (down ? dy <= 0 : dy >= 0) continue;
      final distance = dy.abs() + (other.rect.center.dx - here.dx).abs() / 1000;
      if (distance < best) {
        best = distance;
        target = other;
      }
    }
    target?.requestFocus();
    return target == null ? KeyEventResult.ignored : KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final type = theme.typography;
    final scale = theme.typeScale;
    final widget = this.widget;
    final expanded = widget.expanded;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusMd));
    final hairline = BorderSide(
      color: colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final frame = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: FermanInteractive(
        focusNode: _node,
        onPressed: widget.onPressed,
        semanticLabel: widget.semanticLabel,
        builder: (context, states, _) => FocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          child: Container(
            key: const ValueKey<String>('CommentCard.frame'),
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: radius,
              border: Border.all(
                color: expanded ? colors.accent : colors.borderSubtle,
                width: theme.border.borderWidth,
              ),
              boxShadow: expanded
                  ? [BoxShadow(color: colors.accent, spreadRadius: 1)]
                  : null,
            ),
          ),
        ),
      ),
    );
    final head = Row(
      spacing: theme.space.space2,
      children: [
        Container(
          key: const ValueKey<String>('CommentCard.chip'),
          width: CommentCard.chipSize,
          height: CommentCard.chipSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.chipColor,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusSm),
            ),
          ),
          child: Icon(
            widget.icon,
            size: CommentCard.chipIconSize,
            strokeWidth: CommentCard.chipIconStroke,
            color: widget.iconColor ?? theme.ramps.paper900,
          ),
        ),
        Expanded(
          child: Text(
            widget.author,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: type.bodyStrong.copyWith(color: colors.textPrimary),
          ),
        ),
        Text(
          widget.time,
          style: type.caption.copyWith(
            color: colors.textTertiary,
            fontFeatures: scale.numericTabular,
          ),
        ),
        if (widget.resolved)
          Icon(
            IconName.circleCheck,
            size: CommentCard.resolvedIconSize,
            color: colors.successSolid,
          ),
      ],
    );
    final quote = Text(
      widget.quote,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: type.body.copyWith(
        fontFamily: scale.fontDocSample.family,
        fontSize: CommentCard.quoteFontSize,
        height: CommentCard.quoteLineHeight / CommentCard.quoteFontSize,
        fontWeight: scale.weightRegular,
        color: colors.textSecondary,
      ),
    );
    final text = widget.text;
    final showReplies = expanded && widget.replies.isNotEmpty;
    final repliesLabel = widget.repliesLabel;
    final informative = <Widget>[
      head,
      quote,
      if (text != null)
        Text(text, style: type.body.copyWith(color: colors.textPrimary)),
      if (showReplies)
        Container(
          decoration: BoxDecoration(border: BorderDirectional(top: hairline)),
          padding: EdgeInsetsDirectional.only(
            top: theme.space.space2,
            start: theme.space.space2_5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space2,
            children: [
              for (final reply in widget.replies)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space0_5,
                  children: [
                    Row(
                      spacing: theme.space.space2,
                      children: [
                        Flexible(
                          child: Text(
                            reply.author,
                            style: type.caption.copyWith(
                              fontWeight: scale.weightSemibold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          reply.time,
                          style: type.caption.copyWith(
                            color: colors.textTertiary,
                            fontFeatures: scale.numericTabular,
                          ),
                        ),
                      ],
                    ),
                    Text(reply.text, style: type.body),
                  ],
                ),
            ],
          ),
        ),
      if (!expanded && widget.replies.isNotEmpty && repliesLabel != null)
        Text(
          repliesLabel,
          style: type.caption.copyWith(color: colors.textAccent),
        ),
    ];
    final compose = expanded && widget.composing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space1_5,
            children: [
              TextField(
                size: FieldSize.sm,
                controller: _reply,
                autofocus: true,
                placeholder: widget.replyPlaceholder,
                semanticLabel: widget.replyPlaceholder,
                onSubmitted: _send,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: theme.space.space1_5,
                children: [
                  Button(
                    variant: ButtonVariant.ghost,
                    size: ButtonSize.sm,
                    icon: IconName.check,
                    onPressed: widget.onResolve,
                    child: Text(widget.resolveLabel),
                  ),
                  Button(
                    variant: ButtonVariant.primary,
                    size: ButtonSize.sm,
                    onPressed: widget.onReply == null ? null : _send,
                    disabled: !_hasReply,
                    child: Text(widget.replyLabel),
                  ),
                ],
              ),
            ],
          )
        : null;
    final resolvedBy = widget.resolvedBy;
    final footer = resolvedBy == null
        ? null
        : Row(
            spacing: theme.space.space2,
            children: [
              Expanded(
                child: IgnorePointer(
                  child: Text(
                    resolvedBy,
                    style: type.caption.copyWith(color: colors.textTertiary),
                  ),
                ),
              ),
              Button(
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                icon: IconName.rotateCcw,
                onPressed: widget.onReopen,
                child: Text(widget.reopenLabel),
              ),
            ],
          );
    // The frame is the button; the content sits over it, letting clicks on
    // its text through to the frame, so the reply field and the buttons are
    // not inside the card's button (Space and Enter stay theirs).
    final content = Padding(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: CommentCard.paddingY,
        horizontal: theme.space.space2_5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space1_5,
        children: [
          IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space1_5,
              children: informative,
            ),
          ),
          ?compose,
          ?footer,
        ],
      ),
    );
    Widget card = Stack(
      children: [
        Positioned.fill(child: frame),
        content,
      ],
    );
    if (widget.resolved) {
      card = Opacity(opacity: CommentCard.resolvedOpacity, child: card);
    }
    return Semantics(container: true, explicitChildNodes: true, child: card);
  }
}
