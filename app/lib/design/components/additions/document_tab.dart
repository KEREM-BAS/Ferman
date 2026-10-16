import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:intl/intl.dart' show Bidi;

/// One open document in the title bar's tab strip, the DS addition
/// `DocumentTab` (`FmWindow.dc.html` lines 21–28; `DS additions.dc.html`
/// lines 62–65; `--doctab-*` in `fm-additions.css`).
///
/// - **Active** ([active]): a 32 px tab on the panel surface with a subtle
///   border and 8 px top corners, attached to the mode bar below: it
///   reaches 1 px below its box (`margin-bottom: -1px`) to cover the title
///   bar's bottom border. The name is in the strong body style.
/// - **Idle:** a 28 px (`--doctab-h`) rounded row in the secondary text
///   colour, 4 px above the bottom; the surface tints on hover.
/// - **Unsaved** ([unsaved]): a 7 px dot replaces the close button (fix 4),
///   and screen readers hear the name and [unsavedLabel].
/// - **Loading** ([loading]): [spinner] (the design's 12 px Spinner
///   "Opening", passed by the caller) replaces the icon.
/// - **Locked or repaired:** [icon] is `lock`, `wrench` or `file-x`
///   instead of `file-text`.
/// - **Close:** the active clean tab shows an extra-small close button
///   (the design's xs IconButton "Close document") that calls [onClose],
///   with [closeLabel] and the platform [closeShortcut] (⌘W, Ctrl+W) in
///   its tooltip. Idle clean tabs keep its space empty, as drawn.
///
/// The name is ellipsized and takes its own direction (`dir="auto"`); the
/// full name shows in a tooltip over the icon and name (the design's
/// `title`). The tab is 188 px wide (`--doctab-w`) and never narrower than
/// 112 px (`--doctab-w-min`) unless its parent forces it.
///
/// **Keyboard:** Enter and Space call [onPressed]; focus shows the inset
/// ring as on ModeTabs (G22, not drawn). Inside a [DocumentTabStrip] the
/// arrow keys move between tabs. ⌘W and Ctrl+W close the active document
/// through the app's shortcut table, not through the tab.
///
/// **Semantics:** a tab named by the file name (plus [unsavedLabel] when
/// unsaved) that says whether it is selected.
class DocumentTab extends StatefulWidget {
  /// A tab for the document [name].
  const new({
    required this.name,
    required this.unsavedLabel,
    required this.closeLabel,
    super.key,
    this.active = false,
    this.unsaved = false,
    this.loading = false,
    this.icon = IconName.fileText,
    this.onPressed,
    this.onClose,
    this.closeShortcut,
    this.spinner,
    this.focusNode,
  });

  /// The file name, shown ellipsized and in full in the tooltip.
  final String name;

  /// Whether this is the document shown below.
  final bool active;

  /// Whether the document has unsaved changes.
  final bool unsaved;

  /// Whether the document is still opening.
  final bool loading;

  /// The glyph before the name: `file-text`, or `lock` for a locked file,
  /// `wrench` for a repaired one, `file-x` for a broken one.
  final IconName icon;

  /// Called when the tab is activated; null makes it inert.
  final VoidCallback? onPressed;

  /// Called by the close button of the active clean tab; null hides it.
  final VoidCallback? onClose;

  /// The localized "Unsaved changes", read after the name when [unsaved].
  /// Not a design-system prop.
  final String unsavedLabel;

  /// The localized "Close document": the close button's tooltip and name.
  /// Not a design-system prop.
  final String closeLabel;

  /// The close shortcut as key caps for the platform (`KeyCaps`, ⌘ W or
  /// Ctrl W), shown in the close button's tooltip. Not a design-system
  /// prop.
  final List<String>? closeShortcut;

  /// The loading indicator shown in place of the icon while [loading]: the
  /// design's 12 px Spinner labelled "Opening". Not a design-system prop:
  /// the Spinner is another component, so the caller passes it.
  final Widget? spinner;

  /// The focus node; one is created when null. [DocumentTabStrip] passes
  /// its own. Not a design-system prop.
  final FocusNode? focusNode;

  /// `height: 32px` of the active tab and of the idle tab's outer box
  /// (`FmWindow.dc.html` line 23).
  static const double height = 32;

  /// The unsaved dot: `width: 7px; height: 7px`.
  static const double dotSize = 7;

  /// `margin-bottom: -1px` of the active tab, which covers the title bar's
  /// bottom border.
  static const double activeOverlap = 1;

  /// This tab with [node] as its focus node, for [DocumentTabStrip].
  DocumentTab _withFocusNode(FocusNode node) => DocumentTab(
    key: key,
    name: name,
    unsavedLabel: unsavedLabel,
    closeLabel: closeLabel,
    active: active,
    unsaved: unsaved,
    loading: loading,
    icon: icon,
    onPressed: onPressed,
    onClose: onClose,
    closeShortcut: closeShortcut,
    spinner: spinner,
    focusNode: node,
  );

  @override
  State<DocumentTab> createState() => _DocumentTabState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('name', name))
      ..add(FlagProperty('active', value: active, ifTrue: 'active'))
      ..add(FlagProperty('unsaved', value: unsaved, ifTrue: 'unsaved'))
      ..add(FlagProperty('loading', value: loading, ifTrue: 'loading'))
      ..add(
        EnumProperty<IconName>('icon', icon, defaultValue: IconName.fileText),
      )
      ..add(
        FlagProperty('closable', value: onClose != null, ifTrue: 'closable'),
      );
  }
}

class _DocumentTabState extends State<DocumentTab> {
  FocusNode? _own;

  FocusNode get _node =>
      widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'DocumentTab'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(DocumentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.focusNode ?? _own;
    if (old != _node) {
      old?.removeListener(_onFocusChange);
      _node.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _own?.dispose();
    super.dispose();
  }

  // Rebuilds when focus moves between the tab and its close button.
  void _onFocusChange() => setState(() {});

  /// The direction of the file name from its first strong character, as
  /// `dir="auto"`; null keeps the ambient direction.
  static TextDirection? _directionOf(String text) {
    if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
    if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return FermanInteractive(
      focusNode: _node,
      onPressed: widget.onPressed,
      selected: active,
      semanticsRole: SemanticsRole.tab,
      isButton: false,
      semanticLabel: widget.name,
      builder: (context, states, _) => Semantics(
        // A tab always states whether it is selected; FermanInteractive sets
        // only the selected one.
        selected: active ? null : false,
        child: _visual(context, states),
      ),
    );
  }

  Widget _visual(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final active = widget.active || states.contains(WidgetState.selected);
    // The ring marks the tab itself, not its close button.
    final closeFocused = _node.hasFocus && !_node.hasPrimaryFocus;
    final ring = states.contains(WidgetState.focused) && !closeFocused;
    final iconSize = theme.density.iconSm;
    final spinner = widget.spinner;
    final leading = widget.loading
        ? SizedBox.square(
            dimension: iconSize,
            child: spinner == null ? null : Center(child: spinner),
          )
        : Icon(widget.icon, size: iconSize, color: colors.iconSecondary);
    final name = Text(
      widget.name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      textDirection: _directionOf(widget.name),
      style: active
          ? theme.typography.bodyStrong.copyWith(color: colors.textPrimary)
          : theme.typography.body.copyWith(color: colors.textSecondary),
    );
    final slot = theme.density.controlHXs;
    final Widget trailing;
    if (widget.unsaved) {
      trailing = Semantics(
        label: widget.unsavedLabel,
        child: SizedBox.square(
          dimension: slot,
          child: Center(
            child: SizedBox.square(
              dimension: DocumentTab.dotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? colors.iconPrimary : colors.iconSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    } else if (active && widget.onClose != null) {
      trailing = _CloseButton(
        label: widget.closeLabel,
        shortcut: widget.closeShortcut,
        onPressed: widget.onClose,
      );
    } else {
      trailing = SizedBox(width: slot);
    }
    final row = Row(
      spacing: theme.space.space1_5,
      children: [
        Expanded(
          child: Tooltip(
            message: widget.name,
            excludeFromSemantics: true,
            child: ExcludeSemantics(
              child: Row(
                spacing: theme.space.space1_5,
                children: [
                  leading,
                  Expanded(child: name),
                ],
              ),
            ),
          ),
        ),
        trailing,
      ],
    );
    final padding = EdgeInsetsDirectional.only(
      start: theme.space.space2_5,
      end: theme.space.space1,
    );
    final Widget tab;
    if (active) {
      final side = BorderSide(
        color: colors.borderSubtle,
        width: theme.border.borderWidth,
      );
      final radius = BorderRadius.vertical(
        top: Radius.circular(theme.radius.radiusLg),
      );
      tab = Transform.translate(
        offset: const Offset(0, DocumentTab.activeOverlap),
        child: _withRing(
          visible: ring,
          borderRadius: radius,
          child: Container(
            height: DocumentTab.height,
            padding: padding,
            decoration: BoxDecoration(
              color: colors.surfacePanel,
              border: BorderDirectional(top: side, start: side, end: side),
              borderRadius: radius,
            ),
            child: row,
          ),
        ),
      );
    } else {
      final radius = BorderRadius.all(Radius.circular(theme.radius.radiusMd));
      final hovered = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      final background = pressed
          ? colors.surfacePressed
          : (hovered ? colors.surfaceHover : const Color(0x00000000));
      tab = SizedBox(
        height: DocumentTab.height,
        child: Padding(
          padding: EdgeInsetsDirectional.only(bottom: theme.space.space1),
          child: Center(
            child: _withRing(
              visible: ring,
              borderRadius: radius,
              child: AnimatedContainer(
                duration: theme.motion.durInstant,
                curve: theme.motion.easeOut,
                height: theme.size.doctabH,
                padding: padding,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: radius,
                ),
                child: row,
              ),
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: theme.size.doctabWMin,
        maxWidth: theme.size.doctabW,
      ),
      child: tab,
    );
  }

  /// [child] with the inset focus ring painted over it while [visible].
  ///
  /// The ring is a sibling of the tab's content, not its parent, so showing
  /// or hiding it never rebuilds the content: the close button inside keeps
  /// its state and its focus.
  static Widget _withRing({
    required bool visible,
    required BorderRadiusGeometry borderRadius,
    required Widget child,
  }) => Stack(
    children: [
      child,
      PositionedDirectional(
        start: 0,
        end: 0,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: FocusRing(
            visible: visible,
            style: FocusRingStyle.inset,
            borderRadius: borderRadius,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ],
  );
}

/// The close button of the active clean tab: the design's xs ghost
/// IconButton (`.fm-iconbtn--xs`: 22 px, `--radius-xs`, a 14 px `x`).
class _CloseButton extends StatelessWidget {
  const new({
    required this.label,
    required this.shortcut,
    required this.onPressed,
  });

  final String label;
  final List<String>? shortcut;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FermanInteractive(
    onPressed: onPressed,
    tooltip: label,
    tooltipShortcut: shortcut,
    semanticLabel: label,
    builder: (context, states, _) {
      final theme = context.ferman;
      final colors = theme.colors;
      final hovered = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      final disabled = states.contains(WidgetState.disabled);
      final radius = BorderRadius.all(Radius.circular(theme.radius.radiusXs));
      final Color background;
      if (disabled) {
        background = const Color(0x00000000);
      } else if (pressed) {
        background = colors.surfacePressed;
      } else if (hovered) {
        background = colors.surfaceHover;
      } else {
        background = const Color(0x00000000);
      }
      final Color glyph;
      if (disabled) {
        glyph = colors.iconDisabled;
      } else if (hovered) {
        glyph = colors.textPrimary;
      } else {
        glyph = colors.iconPrimary;
      }
      return FocusRing(
        visible: states.contains(WidgetState.focused),
        borderRadius: radius,
        child: AnimatedContainer(
          duration: theme.motion.durInstant,
          curve: theme.motion.easeOut,
          width: theme.density.controlHXs,
          height: theme.density.controlHXs,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: radius),
          child: Icon(IconName.x, size: theme.density.iconSm, color: glyph),
        ),
      );
    },
  );
}

/// The title bar's strip of open documents: the tab list "Open documents"
/// of `FmWindow` (`FmWindow.dc.html` lines 21–27). Not a design-system
/// component: the container that gives [DocumentTab]s their tab-list
/// semantics and arrow keys.
///
/// The [tabs] sit 2 px apart, bottom-aligned 6 px below the top of the
/// title bar, each 188 px wide and shrinking toward 112 px when space runs
/// out. After them come [overflow], the design's "+N" ghost small Button
/// with a chevron-down that opens the list of the other documents, and
/// [trailing], the "+" IconButton "Open file" (disabled with the
/// future-version tooltip until M2). Both are other components, so the
/// caller passes them; the strip only places them as drawn.
///
/// **Keyboard:** ArrowLeft and ArrowRight move to the previous and next tab
/// in the visual direction and wrap, and the tab they land on is activated
/// (as on ModeTabs). Only the active tab is a Tab stop.
///
/// **Semantics:** a tab bar named [semanticLabel] ("Open documents") holding
/// only the tabs; [overflow] and [trailing] follow it.
class DocumentTabStrip extends StatefulWidget {
  /// A strip of [tabs].
  const new({
    required this.tabs,
    required this.semanticLabel,
    super.key,
    this.overflow,
    this.trailing,
  });

  /// The open documents, in order.
  final List<DocumentTab> tabs;

  /// The accessible name of the tab list, the localized "Open documents".
  final String semanticLabel;

  /// The "+N" overflow button, when some documents do not fit.
  final Widget? overflow;

  /// The "+" open button.
  final Widget? trailing;

  /// `padding-inline-start: 2px` before the overflow button.
  static const double overflowGap = 2;

  @override
  State<DocumentTabStrip> createState() => _DocumentTabStripState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('tabs', tabs.length))
      ..add(StringProperty('semanticLabel', semanticLabel));
  }
}

class _DocumentTabStripState extends State<DocumentTabStrip> {
  final List<FocusNode> _nodes = [];

  void _syncNodes() {
    final count = widget.tabs.length;
    while (_nodes.length < count) {
      _nodes.add(FocusNode(debugLabel: 'DocumentTabStrip ${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final step = RovingFocus.stepFor(event, Directionality.of(context));
    if (step == null) return KeyEventResult.ignored;
    // Only when a tab itself has focus, not its close button.
    final from = _nodes.indexWhere((node) => node.hasPrimaryFocus);
    if (from < 0) return KeyEventResult.ignored;
    final tabs = widget.tabs;
    final to = RovingFocus.target(
      from,
      tabs.length,
      step,
      (i) => tabs[i].onPressed != null,
    );
    if (to == null || to == from) return KeyEventResult.handled;
    _nodes[to].requestFocus();
    tabs[to].onPressed?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes();
    final theme = context.ferman;
    final tabs = widget.tabs;
    final active = tabs.indexWhere((tab) => tab.active);
    final stop = active < 0 ? 0 : active;
    Widget list = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: theme.space.space0_5,
      children: [
        for (var i = 0; i < tabs.length; i++)
          Flexible(
            child: tabs[i]._withFocusNode(_nodes[i]..skipTraversal = i != stop),
          ),
      ],
    );
    list = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.tabBar,
      label: widget.semanticLabel,
      child: Focus(
        canRequestFocus: false,
        includeSemantics: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: list,
      ),
    );
    Widget slot(Widget child, {double start = 0}) => SizedBox(
      height: DocumentTab.height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: start,
          bottom: theme.space.space1,
        ),
        child: Center(child: child),
      ),
    );
    final overflow = widget.overflow;
    final trailing = widget.trailing;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.space.space1_5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: theme.space.space0_5,
        children: [
          Flexible(child: list),
          if (overflow != null)
            slot(overflow, start: DocumentTabStrip.overflowGap),
          if (trailing != null) slot(trailing),
        ],
      ),
    );
  }
}
