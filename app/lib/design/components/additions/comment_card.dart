import 'package:ferman/design/components/annotations/sticky_note.dart';
import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A comment in the Comments panel list, a DS addition drawn inline in
/// `FmComments.dc.html` (lines 25 to 35, the card styles on line 76).
///
/// A raised card (a subtle 1 px hairline, then 9 px by 10 px padding,
/// medium corners) stacking, 6 px apart:
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
/// board's “…”). [NoteReply.mentions] show in the accent colour. Typing `@` in
/// the reply field lists [people] who match, under the field; ↑ and ↓ move, and
/// Enter or a click puts the name in (a4-2).
///
/// **Keyboard.** The card is a button: Enter and Space call [onPressed]
/// (expand and select the annotation). ArrowUp and ArrowDown move to the
/// card above or below and scroll it into view (not drawn); at the first
/// or last card they do nothing, so focus stays in the list. The reply
/// field and the buttons are separate Tab stops; Enter in the field or the
/// Reply button sends a non-empty reply through [onReply] and clears the
/// field, and focus returns to (or stays in) the field for the next reply.
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
    this.reopenDisabledReason,
    this.iconColor,
    this.repliesLabel,
    this.replyPlaceholder,
    this.people = const [],
    this.peopleLabel,
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

  /// Why [onReopen] is null, when it is.
  final String? reopenDisabledReason;

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

  /// The names `@` suggests: people who already commented in this file.
  final List<String> people;

  /// The heading of the list of [people], the localized "People in this
  /// document".
  final String? peopleLabel;

  /// The width of the list of [people] (`width: 220px`).
  static const double peopleWidth = 220;

  /// A row of the list of [people] (`height: 30px`).
  static const double personHeight = 30;

  /// The initials chip of a row (`width` and `height: 20px`).
  static const double personChip = 20;

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

/// A reply's text, its mentions marked.
TextSpan _mentioned(NoteReply reply, Color accent, FontWeight weight) {
  if (reply.mentions.isEmpty) return TextSpan(text: reply.text);
  final names = [...reply.mentions]
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    names.map((name) => '@${RegExp.escape(name)}').join('|'),
  );
  final parts = <InlineSpan>[];
  var at = 0;
  for (final match in pattern.allMatches(reply.text)) {
    parts
      ..add(TextSpan(text: reply.text.substring(at, match.start)))
      ..add(
        TextSpan(
          text: match[0],
          style: TextStyle(color: accent, fontWeight: weight),
        ),
      );
    at = match.end;
  }
  parts.add(TextSpan(text: reply.text.substring(at)));
  return TextSpan(children: parts);
}

/// The reply field's text, the `@word` at the caret in the accent colour.
class _MentionController extends TextEditingController {
  Color? accent;

  /// What follows the `@` of the word the caret is in, or null.
  String? get mention {
    final caret = selection.isCollapsed ? selection.start : -1;
    if (caret < 0 || caret > text.length) return null;
    final before = text.substring(0, caret);
    final at = before.lastIndexOf('@');
    if (at < 0 || (at > 0 && before[at - 1].trim().isNotEmpty)) return null;
    return before.substring(at + 1);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final word = mention;
    final color = accent;
    if (word == null || color == null) {
      return super.buildTextSpan(
        context: context,
        withComposing: withComposing,
        style: style,
      );
    }
    final end = selection.start;
    final start = end - word.length - 1;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(color: color),
        ),
        TextSpan(text: text.substring(end)),
      ],
    );
  }
}

/// The focus node of a card, so the arrow keys find the other cards.
class _CommentCardNode extends FocusNode {
  new() : super(debugLabel: 'CommentCard');
}

class _CommentCardState extends State<CommentCard> {
  final _CommentCardNode _node = _CommentCardNode();
  final _MentionController _reply = _MentionController();
  final FocusNode _replyNode = FocusNode(debugLabel: 'CommentCard reply');
  int _person = 0;

  @override
  void initState() {
    super.initState();
    _reply.addListener(_onReplyText);
  }

  @override
  void didUpdateWidget(CommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final composing = widget.composing && widget.expanded;
    if (composing && !(oldWidget.composing && oldWidget.expanded)) {
      _focusReply();
    }
  }

  /// After this frame, once the field is in the focus tree; `autofocus` alone
  /// gives way to a focus the window already has.
  void _focusReply() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _replyNode.requestFocus();
  });

  @override
  void dispose() {
    _reply
      ..removeListener(_onReplyText)
      ..dispose();
    _replyNode.dispose();
    _node.dispose();
    super.dispose();
  }

  bool _hasReply = false;

  void _onReplyText() {
    final has = _reply.text.trim().isNotEmpty;
    if (has != _hasReply) setState(() => _hasReply = has);
    // The list of people follows the text and the caret.
    setState(() => _person = 0);
  }

  /// The people the `@word` before the caret could name.
  List<String> get _matches {
    final query = _reply.mention;
    if (query == null) return const [];
    final casing = LocaleCasing.of(context);
    final folded = casing.lower(query);
    return [
      for (final person in widget.people)
        if (casing.lower(person).startsWith(folded)) person,
    ];
  }

  void _pick(String person) {
    final selection = _reply.selection;
    final start = selection.start - (_reply.mention?.length ?? 0);
    final text = _reply.text.replaceRange(start, selection.start, '$person ');
    _reply.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + person.length + 1),
    );
    _replyNode.requestFocus();
  }

  /// ↑, ↓ and Enter while the list of people shows.
  KeyEventResult _onReplyKey(FocusNode node, KeyEvent event) {
    final matches = _matches;
    if (matches.isEmpty ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _person = (_person + 1) % matches.length);
      case LogicalKeyboardKey.arrowUp:
        setState(() => _person = (_person - 1) % matches.length);
      case LogicalKeyboardKey.enter:
        _pick(matches[_person.clamp(0, matches.length - 1)]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _people(FermanTheme theme, List<String> matches) {
    final colors = theme.colors;
    final type = theme.typography;
    return Container(
      width: CommentCard.peopleWidth,
      padding: EdgeInsetsDirectional.all(theme.space.space1),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
        boxShadow: theme.elevation.shadowPopover,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.peopleLabel case final label?)
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: theme.space.space1,
                horizontal: theme.space.space2,
              ),
              child: Text(
                label,
                style: type.label.copyWith(color: colors.textTertiary),
              ),
            ),
          for (final (i, person) in matches.indexed)
            FermanInteractive(
              onPressed: () => _pick(person),
              semanticLabel: person,
              selected: i == _person,
              builder: (context, states, _) => Container(
                height: CommentCard.personHeight,
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space2,
                ),
                decoration: BoxDecoration(
                  color: i == _person ? colors.surfaceSelectedStrong : null,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusSm),
                  ),
                ),
                child: Row(
                  spacing: theme.space.space2,
                  children: [
                    Container(
                      width: CommentCard.personChip,
                      height: CommentCard.personChip,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.all(
                          Radius.circular(theme.radius.radiusSm),
                        ),
                      ),
                      child: Text(
                        _initials(person),
                        style: type.caption.copyWith(
                          fontWeight: theme.typeScale.weightSemibold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        person,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.body.copyWith(
                          color: i == _person
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The first letters of the last two words of [name].
  static String _initials(String name) {
    final words = name
        .split(' ')
        .where((word) => word.isNotEmpty && !word.endsWith('.'))
        .toList();
    return words.reversed
        .take(2)
        .toList()
        .reversed
        .map((word) => String.fromCharCode(word.runes.first))
        .join();
  }

  void _send([String? _]) {
    // Focus goes back to the field every time. After Enter it never leaves
    // (EditableText's unfocus and this land in one focus update); after
    // the Reply button it moves before Reply turns disabled, so it never
    // falls back to Resolve.
    _replyNode.requestFocus();
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
    if (target != null) {
      target.requestFocus();
      final targetContext = target.context;
      if (targetContext != null) {
        // No animation, as ModeTabs scrolls a tab into view.
        Scrollable.ensureVisible(
          targetContext,
          alignmentPolicy: down
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    }
    // Stop at the first and last card: the app's directional focus must
    // not take the arrows out of the list.
    return KeyEventResult.handled;
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
                    Text.rich(
                      _mentioned(reply, colors.textAccent, scale.weightMedium),
                      style: type.body,
                    ),
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
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                includeSemantics: false,
                onKeyEvent: _onReplyKey,
                child: TextField(
                  size: FieldSize.sm,
                  controller: _reply..accent = colors.textAccent,
                  focusNode: _replyNode,
                  autofocus: true,
                  placeholder: widget.replyPlaceholder,
                  semanticLabel: widget.replyPlaceholder,
                  onSubmitted: _send,
                ),
              ),
              if (_matches case final matches when matches.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _people(theme, matches),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: theme.space.space1_5,
                children: [
                  if (widget.resolvedBy == null)
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
                disabled: widget.onReopen == null,
                disabledReason: widget.reopenDisabledReason,
                child: Text(widget.reopenLabel),
              ),
            ],
          );
    // The frame is the button; the content sits over it, letting clicks on
    // its text through to the frame, so the reply field and the buttons are
    // not inside the card's button (Space and Enter stay theirs). The frame
    // draws the 1 px border, so the content sits inside it as well as the
    // padding (`padding: 9px 10px; border: 1px`).
    final borderWidth = theme.border.borderWidth;
    final content = Padding(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: CommentCard.paddingY + borderWidth,
        horizontal: theme.space.space2_5 + borderWidth,
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
