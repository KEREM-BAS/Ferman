import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The match options of a [SearchReplaceBar] (the bundle's
/// `onToggleOption` keys).
enum SearchOption {
  /// Match upper and lower case exactly.
  matchCase,

  /// Match whole words only.
  wholeWord,

  /// Read the query as a regular expression.
  regex,
}

/// The localized texts of a [SearchReplaceBar]: the bundle's English names,
/// placeholders, tooltips and count. Not a design-system type.
@immutable
class SearchReplaceBarLabels {
  /// Creates the texts.
  const new({
    required this.region,
    required this.find,
    required this.replaceWith,
    required this.matchCase,
    required this.wholeWord,
    required this.regex,
    required this.showReplace,
    required this.hideReplace,
    required this.previous,
    required this.next,
    required this.close,
    required this.replace,
    required this.replaceAll,
    required this.noResults,
    required this.count,
    this.previousShortcut,
    this.nextShortcut,
    this.closeShortcut,
  });

  /// The bar's accessible name, "Find and replace".
  final String region;

  /// The find field's placeholder and name, "Find".
  final String find;

  /// The replace field's placeholder and name, "Replace with".
  final String replaceWith;

  /// The match-case toggle's name and tooltip, "Match case".
  final String matchCase;

  /// The whole-word toggle's name and tooltip, "Whole word".
  final String wholeWord;

  /// The regex toggle's name and tooltip, "Regular expression".
  final String regex;

  /// The disclosure button's name while the replace row is hidden, "Show
  /// replace".
  final String showReplace;

  /// Its name while the replace row shows, "Hide replace".
  final String hideReplace;

  /// The previous button's name and tooltip, "Previous match".
  final String previous;

  /// The next button's name and tooltip, "Next match".
  final String next;

  /// The close button's name and tooltip, "Close".
  final String close;

  /// The Replace button, "Replace".
  final String replace;

  /// The Replace all button, "Replace all".
  final String replaceAll;

  /// The count when nothing matches, "No results".
  final String noResults;

  /// The count text for the `current` match of `total`, "N of M", with
  /// the numbers formatted for the region setting.
  final String Function(int current, int total) count;

  /// The key caps after "Previous match" (⇧ ↵); null shows none.
  final List<String>? previousShortcut;

  /// The key caps after "Next match" (↵); null shows none.
  final List<String>? nextShortcut;

  /// The key caps after "Close" (Esc); null shows none.
  final List<String>? closeShortcut;
}

/// The floating find bar, the design-system `SearchReplaceBar` component
/// (`components/editing/editing.css`, `.fm-search`; `SearchReplaceBar.jsx`).
///
/// A 440 px raised bar (at most the available width) with large corners
/// and the popover shadow. The rows fill its 428 px content box, as
/// `editing.css` is written; the browser render lets the find row's
/// min-content overflow the 6 px end padding, so its fields come out 8 px
/// wider than here (a design-internal conflict, G76).
/// The find row holds a disclosure button that
/// shows or hides the replace row ([onToggleReplace]), a small find field
/// with a search glyph and the three match options as 20 px toggles
/// ([matchCase], [wholeWord], [regex], reported through [onToggleOption]),
/// the count, and previous, next and close buttons. The count is empty
/// without a query, "N of M" ([SearchReplaceBarLabels.count]) or "No
/// results" in the danger colour; previous, next, Replace and Replace all
/// are disabled while nothing matches. With [showReplace], a second row
/// holds the replace field and the Replace and Replace all buttons. Until
/// replace ships, [replaceDisabledReason] keeps the disclosure, the
/// replace field and both buttons visible but disabled, the reason shown
/// as their tooltip and semantics hint (G10). A
/// [notice] (the honest font notice) shows under the rows in a warning
/// callout.
///
/// The bar is controlled: [query] and [replaceWith] are the fields' texts
/// and edits are reported through [onQueryChanged] and [onReplaceChanged].
///
/// **Keyboard:** Escape anywhere in the bar calls [onClose]; in the find
/// field Enter goes to the next match and Shift+Enter to the previous one.
///
/// For screen readers it is a group named "Find and replace"; the count is
/// a polite live region and the notice a status; the option toggles are
/// toggle buttons.
class SearchReplaceBar extends StatefulWidget {
  /// Creates the bar.
  const new({
    required this.labels,
    super.key,
    this.query = '',
    this.replaceWith = '',
    this.showReplace = false,
    this.current = 0,
    this.total = 0,
    this.matchCase = false,
    this.wholeWord = false,
    this.regex = false,
    this.notice,
    this.onQueryChanged,
    this.onReplaceChanged,
    this.onToggleReplace,
    this.onToggleOption,
    this.onPrevious,
    this.onNext,
    this.onReplace,
    this.onReplaceAll,
    this.onClose,
    this.autofocus = false,
    this.replaceDisabledReason,
    this.regexDisabledReason,
  });

  /// `.fm-search` `width: 440px`.
  static const double width = 440;

  /// `.fm-search__opt` `width` and `height: 20px`.
  static const double optionSize = 20;

  /// `.fm-search__opt` `border-radius: 3px`.
  static const double optionRadius = 3;

  /// `.fm-search__count` `min-width: 64px`.
  static const double countMinWidth = 64;

  /// The replace row's `paddingInlineStart: 30`: under the find field.
  static const double replaceIndent = 30;

  /// The find field's text.
  final String query;

  /// The replace field's text.
  final String replaceWith;

  /// Whether the replace row shows.
  final bool showReplace;

  /// The current match, from 1.
  final int current;

  /// The number of matches.
  final int total;

  /// Whether case must match.
  final bool matchCase;

  /// Whether whole words must match.
  final bool wholeWord;

  /// Whether the query is a regular expression.
  final bool regex;

  /// The warning under the rows; null shows none.
  final String? notice;

  /// Called with the find field's text after each edit.
  final ValueChanged<String>? onQueryChanged;

  /// Called with the replace field's text after each edit.
  final ValueChanged<String>? onReplaceChanged;

  /// Called when the disclosure button is pressed.
  final VoidCallback? onToggleReplace;

  /// Called with an option and its new value when a toggle is pressed.
  // The spec's type (`component_spec.json`, the bundle's
  // `onToggleOption(key, value)`).
  // ignore: avoid_positional_boolean_parameters
  final void Function(SearchOption option, bool value)? onToggleOption;

  /// Called for the previous match (button, Shift+Enter).
  final VoidCallback? onPrevious;

  /// Called for the next match (button, Enter).
  final VoidCallback? onNext;

  /// Called when Replace is pressed.
  final VoidCallback? onReplace;

  /// Called when Replace all is pressed.
  final VoidCallback? onReplaceAll;

  /// Called on Escape and by the close button.
  final VoidCallback? onClose;

  /// Whether the find field takes focus when the bar appears.
  final bool autofocus;

  /// Why replace is unavailable: the localized "Available in a future
  /// version" until replace ships (G10). It disables the disclosure, the
  /// replace field and the Replace and Replace all buttons, which stay
  /// focusable with the reason as their tooltip and hint. Null leaves
  /// replace enabled. Not a design-system prop.
  final String? replaceDisabledReason;

  /// Why the regular-expression toggle is unavailable: the localized
  /// "Available in a future version" until regular expressions ship (G10).
  final String? regexDisabledReason;

  /// The localized texts. Not a design-system prop.
  final SearchReplaceBarLabels labels;

  /// The count text: empty without a query, else "No results" or "N of M".
  String get countText {
    if (query.isEmpty) return '';
    if (total == 0) return labels.noResults;
    return labels.count(current, total);
  }

  @override
  State<SearchReplaceBar> createState() => _SearchReplaceBarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('query', query))
      ..add(StringProperty('replaceWith', replaceWith, defaultValue: ''))
      ..add(FlagProperty('showReplace', value: showReplace, ifTrue: 'replace'))
      ..add(IntProperty('current', current))
      ..add(IntProperty('total', total))
      ..add(FlagProperty('matchCase', value: matchCase, ifTrue: 'match case'))
      ..add(FlagProperty('wholeWord', value: wholeWord, ifTrue: 'whole word'))
      ..add(FlagProperty('regex', value: regex, ifTrue: 'regex'))
      ..add(StringProperty('notice', notice, defaultValue: null))
      ..add(
        StringProperty(
          'replaceDisabledReason',
          replaceDisabledReason,
          defaultValue: null,
        ),
      );
  }
}

class _SearchReplaceBarState extends State<SearchReplaceBar> {
  late final TextEditingController _find = TextEditingController(
    text: widget.query,
  );
  late final TextEditingController _replace = TextEditingController(
    text: widget.replaceWith,
  );
  final FocusNode _findNode = FocusNode(debugLabel: 'SearchReplaceBar find');
  final FocusNode _replaceNode = FocusNode(
    debugLabel: 'SearchReplaceBar replace',
  );

  @override
  void didUpdateWidget(SearchReplaceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_find, widget.query);
    _sync(_replace, widget.replaceWith);
  }

  static void _sync(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    _findNode.dispose();
    _replaceNode.dispose();
    super.dispose();
  }

  KeyEventResult _onBarKey(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.onClose != null) {
      widget.onClose!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onFindKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      widget.onPrevious?.call();
    } else {
      widget.onNext?.call();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final widget = this.widget;
    final labels = widget.labels;
    final hasMatches = widget.total > 0;
    final none = widget.query.isNotEmpty && widget.total == 0;
    final replaceReason = widget.replaceDisabledReason;
    final replaceOff = replaceReason != null;
    final textStyle = FieldBox.textStyleOf(
      theme,
      FieldSize.sm,
      color: colors.textPrimary,
    );
    final iconSize = FieldBox.iconSizeOf(theme, FieldSize.sm);
    final findField = Expanded(
      child: FieldBox(
        size: FieldSize.sm,
        child: Row(
          spacing: FieldBox.contentGap,
          children: [
            Icon(IconName.search, size: iconSize, color: colors.iconSecondary),
            Expanded(
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                includeSemantics: false,
                onKeyEvent: _onFindKey,
                child: MergeSemantics(
                  child: Semantics(
                    label: labels.find,
                    child: FieldInput(
                      controller: _find,
                      focusNode: _findNode,
                      style: textStyle,
                      placeholder: labels.find,
                      autofocus: widget.autofocus,
                      onChanged: widget.onQueryChanged,
                      onSubmitted: (_) => widget.onNext?.call(),
                      onEditingComplete: () {},
                    ),
                  ),
                ),
              ),
            ),
            _OptionToggle(
              icon: IconName.caseSensitive,
              label: labels.matchCase,
              on: widget.matchCase,
              onToggle: _toggle(SearchOption.matchCase, widget.matchCase),
            ),
            _OptionToggle(
              icon: IconName.wholeWord,
              label: labels.wholeWord,
              on: widget.wholeWord,
              onToggle: _toggle(SearchOption.wholeWord, widget.wholeWord),
            ),
            _OptionToggle(
              icon: IconName.regex,
              label: labels.regex,
              on: widget.regex,
              onToggle: _toggle(SearchOption.regex, widget.regex),
              disabledReason: widget.regexDisabledReason,
            ),
          ],
        ),
      ),
    );
    final count = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: SearchReplaceBar.countMinWidth,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Text(
          widget.countText,
          key: const ValueKey<String>('SearchReplaceBar.count'),
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: theme.typography.caption.copyWith(
            color: none ? colors.danger : colors.textSecondary,
            fontFeatures: theme.typeScale.numericTabular,
          ),
        ),
      ),
    );
    final findRow = Row(
      spacing: theme.space.space1,
      children: [
        IconButton(
          icon: widget.showReplace
              ? IconName.chevronDown
              : IconName.chevronRight,
          label: widget.showReplace ? labels.hideReplace : labels.showReplace,
          size: IconButtonSize.sm,
          showTooltip: false,
          disabled: replaceOff,
          disabledReason: replaceReason,
          onPressed: widget.onToggleReplace,
        ),
        findField,
        count,
        IconButton(
          icon: IconName.chevronUp,
          label: labels.previous,
          size: IconButtonSize.sm,
          shortcut: labels.previousShortcut,
          disabled: !hasMatches,
          onPressed: widget.onPrevious,
        ),
        IconButton(
          icon: IconName.chevronDown,
          label: labels.next,
          size: IconButtonSize.sm,
          shortcut: labels.nextShortcut,
          disabled: !hasMatches,
          onPressed: widget.onNext,
        ),
        IconButton(
          icon: IconName.x,
          label: labels.close,
          size: IconButtonSize.sm,
          shortcut: labels.closeShortcut,
          onPressed: widget.onClose,
        ),
      ],
    );
    final replaceRow = widget.showReplace
        ? Padding(
            key: const ValueKey<String>('SearchReplaceBar.replaceRow'),
            padding: const EdgeInsetsDirectional.only(
              start: SearchReplaceBar.replaceIndent,
            ),
            child: Row(
              spacing: theme.space.space1,
              children: [
                Expanded(
                  child: FieldBox(
                    size: FieldSize.sm,
                    disabled: replaceOff,
                    child: Row(
                      spacing: FieldBox.contentGap,
                      children: [
                        Icon(
                          IconName.replace,
                          size: iconSize,
                          color: colors.iconSecondary,
                        ),
                        Expanded(
                          child: MergeSemantics(
                            child: Semantics(
                              label: labels.replaceWith,
                              child: FieldInput(
                                controller: _replace,
                                focusNode: _replaceNode,
                                style: textStyle,
                                enabled: !replaceOff,
                                placeholder: labels.replaceWith,
                                onChanged: widget.onReplaceChanged,
                                onEditingComplete: () {},
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Button(
                  size: ButtonSize.sm,
                  disabled: !hasMatches || replaceOff,
                  disabledReason: replaceReason,
                  onPressed: widget.onReplace,
                  child: Text(labels.replace),
                ),
                Button(
                  size: ButtonSize.sm,
                  disabled: !hasMatches || replaceOff,
                  disabledReason: replaceReason,
                  onPressed: widget.onReplaceAll,
                  child: Text(labels.replaceAll),
                ),
              ],
            ),
          )
        : null;
    final notice = widget.notice;
    final noticeBox = notice == null
        ? null
        : Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              key: const ValueKey<String>('SearchReplaceBar.notice'),
              padding: EdgeInsetsDirectional.symmetric(
                vertical: theme.space.space1_5,
                horizontal: theme.space.space2,
              ),
              decoration: BoxDecoration(
                color: colors.warningBg,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusSm),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.space.space1_5,
                children: [
                  Padding(
                    // `.fm-search__notice svg { margin-top: 1px }`.
                    padding: EdgeInsetsDirectional.only(
                      top: theme.space.spacePx,
                    ),
                    child: Icon(
                      IconName.triangleAlert,
                      size: theme.density.iconSm,
                      color: colors.warningSolid,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      notice,
                      style: theme.typography.caption.copyWith(
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
    final bar = SizedBox(
      width: SearchReplaceBar.width,
      child: Container(
        padding: EdgeInsetsDirectional.all(theme.space.space1_5),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusLg),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space1_5,
          children: [findRow, ?replaceRow, ?noticeBox],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: labels.region,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onBarKey,
        child: bar,
      ),
    );
  }

  VoidCallback? _toggle(SearchOption option, bool on) {
    final onToggleOption = widget.onToggleOption;
    if (onToggleOption == null) return null;
    return () => onToggleOption(option, !on);
  }
}

/// A match option toggle (`.fm-search__opt`): 20 px, 3 px corners, the
/// accent-subtle "on" look, the inset focus ring.
class _OptionToggle extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.on,
    required this.onToggle,
    this.disabledReason,
  });

  final IconName icon;
  final String label;
  final bool on;
  final VoidCallback? onToggle;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    const radius = BorderRadius.all(
      Radius.circular(SearchReplaceBar.optionRadius),
    );
    final disabled = disabledReason != null;
    return FermanInteractive(
      onPressed: onToggle,
      disabled: disabled,
      disabledReason: disabledReason,
      toggled: on,
      tooltip: label,
      semanticLabel: label,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final Color? fill;
        final Color glyph;
        if (disabled) {
          fill = null;
          glyph = colors.iconDisabled;
        } else if (on) {
          fill = colors.accentSubtle;
          glyph = colors.textAccent;
        } else if (hovered) {
          fill = colors.surfaceHover;
          glyph = colors.textPrimary;
        } else {
          fill = null;
          glyph = colors.iconSecondary;
        }
        return FocusRing(
          visible: states.contains(WidgetState.focused),
          style: FocusRingStyle.inset,
          borderRadius: radius,
          child: Container(
            width: SearchReplaceBar.optionSize,
            height: SearchReplaceBar.optionSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fill, borderRadius: radius),
            child: Icon(icon, size: theme.density.iconSm, color: glyph),
          ),
        );
      },
    );
  }
}
