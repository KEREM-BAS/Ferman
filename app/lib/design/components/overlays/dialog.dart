import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/foundation/modal_scope.dart';
import 'package:ferman/design/components/overlays/scrim.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The tone of a [Dialog]'s glyph (`.fm-dialog--warning`,
/// `.fm-dialog--danger`).
enum DialogTone {
  /// The accent glyph. The design's `default`.
  standard,

  /// The amber glyph.
  warning,

  /// The red glyph; the dialog is announced as an alert dialog.
  danger,
}

/// The width of a [Dialog] (`.fm-dialog--sm`, `.fm-dialog`,
/// `.fm-dialog--lg`).
enum DialogSize {
  /// `--dialog-w-sm`, 400 px.
  sm,

  /// `--dialog-w-md`, 520 px.
  md,

  /// 640 px.
  lg,
}

/// The order of a [Dialog]'s footer buttons: each system's convention
/// (the f6a and a1-10b notes, G15, G16).
enum DialogButtonOrder {
  /// macOS and Linux, and every other system but Windows: Cancel first,
  /// then the other actions, the affirmative one last at the end (a1-10b:
  /// Cancel, Save; Linux by G15 and Q12).
  cancelFirst,

  /// Windows: the affirmative action first, then the others, then Cancel
  /// (f6a: primary, secondary, then Cancel; a1-10b: Save, Don't save,
  /// Cancel; G16).
  cancelLast;

  /// The convention of [platform]: Windows puts Cancel last, every other
  /// system first.
  static DialogButtonOrder of(TargetPlatform platform) =>
      platform == TargetPlatform.windows ? cancelLast : cancelFirst;

  /// The convention of the system the app runs on (`defaultTargetPlatform`).
  static DialogButtonOrder get current => of(defaultTargetPlatform);

  /// [actions], written in the macOS and Linux order (the affirmative one
  /// last), [alternate] and [cancel] in this order: the buttons apart at
  /// the start of the footer and those lined up at its end, each from the
  /// start. [alternate] (a1-10b's "Don't save") is at the start for
  /// [cancelFirst] and between the actions and [cancel] for [cancelLast].
  ({List<Widget> start, List<Widget> end}) arrange(
    List<Widget> actions, {
    Widget? cancel,
    Widget? alternate,
  }) => switch (this) {
    cancelFirst => (start: [?alternate], end: [?cancel, ...actions]),
    cancelLast => (
      start: const <Widget>[],
      end: [...actions.reversed, ?alternate, ?cancel],
    ),
  };
}

/// A modal (or inline) dialog with a glyph, a question title, a
/// description, a body and footer actions, the design-system `Dialog`
/// component (`components/overlays/Dialog.jsx`, `.fm-dialog`). Never
/// `showDialog`, `AlertDialog` or the Material dialog (ADR 0011); Material
/// has a `Dialog` too, so files that import Material hide it.
///
/// **The box.** A raised surface with large corners and the dialog shadow,
/// [size] wide (and never wider than the space less 16 px each side, nor
/// taller than it less 32 px each way). The head (18 px top, 20 px start,
/// 16 px end) holds the 32 px [icon] glyph in the [tone]'s colours, the
/// [title] in the dialog-title role with [description] under it in prose
/// secondary text, and, with [onClose], the close button at the end (a
/// small `x` [IconButton] named [closeLabel], without a tooltip). [child]
/// is the scrolling body in prose type (16 px by 20 px of padding); the
/// foot ends the box with [actions] and [cancelAction] lined up at the end,
/// 8 px apart, and [footerStart] at the start. Without a body or a foot the
/// box ends under the head (`.fm-dialog__head` has no bottom padding). The
/// box rises in over `--dur-slow`.
///
/// **Button order.** The footer buttons follow the system's convention
/// ([buttonOrder], by default the system the app runs on). On macOS and
/// Linux [alternateAction] stands apart at the start, after [footerStart],
/// and the end holds [cancelAction] first and the affirmative button last
/// (a1-10b: "Don't save" … Cancel, Save; G15). On Windows the end holds
/// the affirmative button first, then the others, then [alternateAction],
/// then [cancelAction] (f6a: primary, secondary, then Cancel; a1-10b:
/// Save, Don't save, Cancel; G16). [actions] are written in the macOS and
/// Linux order, the affirmative button last, and Windows reverses them.
/// Focus moves through the buttons in the order they are drawn.
/// [footerStart] stays at the start on every system.
///
/// **Modal.** Unless [inline], a dialog is shown while [open] in the root
/// [Overlay] (through an [OverlayPortal] at [OverlayChildLocation.rootOverlay];
/// no Material route), centred over a [Scrim] that covers the whole window, the
/// title bar included, wherever the dialog sits in the tree; [ModalScope]
/// counts it while it shows. Tooltips, popovers and menus in the dialog open in
/// the modal layer's own overlay, above the box. The dialog shows only while
/// its route is the current one and its tickers run (an ancestor [TickerMode]
/// that mutes them hides it too): under a route pushed above its own it hides
/// and stops counting, keeping its state, and shows again with focus inside
/// when that route goes. It is modal: screen readers see only the dialog, focus
/// is trapped inside it (Tab and Shift+Tab cycle), and focus goes on open to a
/// child that asks for `autofocus` (the bundle's `data-autofocus`), else to the
/// first focusable control in the body, else to the dialog itself (which shows
/// no ring), and returns on close to where it was. With [onClose], Escape and a
/// pointer down on the scrim call it; [closeLabel] names the scrim as a dismiss
/// target. [inline] draws the box in place, without scrim, modality or trap
/// (boards and the gallery); Escape inside it still calls [onClose].
///
/// **Slots.** The footer buttons are widgets the screen composes.
///
/// For screen readers the dialog is a dialog (an alert dialog for the
/// danger tone) named by [title], with [description] as its hint.
class Dialog extends StatefulWidget {
  /// Creates a dialog asking [title].
  const new({
    required this.title,
    super.key,
    this.open = true,
    this.inline = false,
    this.description,
    this.icon,
    this.tone = DialogTone.standard,
    this.size = DialogSize.md,
    this.child,
    this.actions = const [],
    this.cancelAction,
    this.alternateAction,
    this.buttonOrder,
    this.footerStart,
    this.onClose,
    this.closeLabel = '',
  }) : assert(
         onClose == null || closeLabel != '',
         'A closable dialog needs the localized closeLabel.',
       );

  /// `.fm-dialog--lg` `width`.
  static const double largeWidth = 640;

  /// `.fm-dialog__glyph` `width` and `height`.
  static const double glyphSize = 32;

  /// The glyph's icon size (`Icon size={18}`).
  static const double glyphIconSize = 18;

  /// `.fm-dialog` `max-height: calc(100vh - 64px)`: the space kept above
  /// and below.
  static const double verticalMargin = 64;

  /// `.fm-dialog__head` `padding-top`.
  static const double headTop = 18;

  /// `.fm-dialog__foot` `padding-bottom`.
  static const double footBottom = 18;

  /// `fm-rise-in`: how far the box rises while it fades in.
  static const double riseDistance = 4;

  /// Whether the dialog is shown.
  final bool open;

  /// Whether to draw the box in place, without scrim, modality or focus
  /// trap.
  final bool inline;

  /// The question the dialog asks ("Apply 2 redactions?").
  final String title;

  /// The text under the title; null shows none.
  final String? description;

  /// The glyph in the head; null shows none.
  final IconName? icon;

  /// The colours of the glyph and, for danger, the alert-dialog role.
  final DialogTone tone;

  /// The width.
  final DialogSize size;

  /// The body; null leaves it out.
  final Widget? child;

  /// The footer buttons other than Cancel, written in the macOS and Linux
  /// order (the affirmative button last) and lined up at the end in the
  /// order of [buttonOrder].
  final List<Widget> actions;

  /// The button that dismisses the dialog without acting ("Cancel"): before
  /// [actions] on macOS and Linux, after them on Windows; null shows none.
  /// Not a design-system prop (the bundle's `actions` node holds it).
  final Widget? cancelAction;

  /// The button that closes the dialog another way, without the
  /// affirmative action (a1-10b's "Don't save"): apart at the start of the
  /// footer on macOS and Linux, between [actions] and [cancelAction] on
  /// Windows; null shows none. Not a design-system prop (the bundle passes
  /// it as `footerStart`).
  final Widget? alternateAction;

  /// The order of [actions], [alternateAction] and [cancelAction]; null
  /// follows the system the app runs on ([DialogButtonOrder.current]). Not
  /// a design-system prop.
  final DialogButtonOrder? buttonOrder;

  /// A widget at the start of the footer (a checkbox, a link).
  final Widget? footerStart;

  /// Shows the close button and is called by it, on Escape and on a
  /// pointer down on the scrim; null makes the dialog wait for an action.
  final VoidCallback? onClose;

  /// The localized name of the close button and of the scrim as a dismiss
  /// target ("Close"); required with [onClose].
  final String closeLabel;

  /// The width of a dialog of [size] in [theme].
  static double widthOf(FermanTheme theme, DialogSize size) => switch (size) {
    DialogSize.sm => theme.size.dialogWSm,
    DialogSize.md => theme.size.dialogWMd,
    DialogSize.lg => largeWidth,
  };

  @override
  State<Dialog> createState() => _DialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('open', value: open, ifFalse: 'closed'))
      ..add(FlagProperty('inline', value: inline, ifTrue: 'inline'))
      ..add(StringProperty('title', title))
      ..add(StringProperty('description', description, defaultValue: null))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(
        EnumProperty<DialogTone>(
          'tone',
          tone,
          defaultValue: DialogTone.standard,
        ),
      )
      ..add(EnumProperty<DialogSize>('size', size, defaultValue: DialogSize.md))
      ..add(
        FlagProperty(
          'cancelAction',
          value: cancelAction != null,
          ifTrue: 'has cancel',
        ),
      )
      ..add(
        FlagProperty(
          'alternateAction',
          value: alternateAction != null,
          ifTrue: 'has alternate',
        ),
      )
      ..add(
        EnumProperty<DialogButtonOrder>(
          'buttonOrder',
          buttonOrder,
          defaultValue: null,
        ),
      )
      ..add(
        FlagProperty(
          'closable',
          value: onClose != null,
          ifTrue: 'closes on Escape',
        ),
      );
  }
}

class _DialogState extends State<Dialog> {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'Dialog',
  );
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'Dialog');
  final FocusNode _boxNode = FocusNode(
    debugLabel: 'Dialog box',
    skipTraversal: true,
  );
  final FocusNode _body = FocusNode(
    debugLabel: 'Dialog body',
    canRequestFocus: false,
    skipTraversal: true,
  );
  FocusNode? _restore;
  ModalHandle? _modalHandle;

  /// Whether the route the dialog sits in is the current one and its
  /// tickers run; null before the first [didChangeDependencies].
  bool? _routeVisible;

  bool get _modal => widget.open && !widget.inline;

  /// Whether the modal layer shows: modal, and not under a route pushed
  /// above the dialog's own (the root overlay is not tied to that route).
  bool get _shown => _modal && (_routeVisible ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (visible == _routeVisible) return;
    final first = _routeVisible == null;
    _routeVisible = visible;
    if (first) {
      if (_shown) {
        // Not attached yet, so this only records that the portal starts
        // shown.
        _portal.show();
        _scheduleInitialFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _shown) _openModal();
        });
      }
      return;
    }
    // The overlay cannot change during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(Dialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasModal = oldWidget.open && !oldWidget.inline;
    if (wasModal != _modal) {
      // The overlay cannot be shown or hidden during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void dispose() {
    _closeModal();
    _restoreFocus();
    _scope.dispose();
    _boxNode.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Shows the portal once the dialog is modal on the current route, and
  /// keeps it (hidden, with its state) while a route above covers it until
  /// the dialog closes; counts and focuses the modal layer while it shows
  /// ([_shown]).
  void _sync() {
    if (!mounted) return;
    if (_shown && !_portal.isShowing) {
      _portal.show();
    } else if (!_modal && _portal.isShowing) {
      _portal.hide();
    }
    if (_shown) {
      if (_modalHandle == null) {
        _openModal();
        _scheduleInitialFocus();
      }
    } else {
      // By the handle: an inline switch disposes the portal, which then
      // reads as hidden already.
      _closeModal();
      // Only a real close gives focus back; under a route above, focus
      // stays with that route.
      if (!_modal) _restoreFocus();
    }
  }

  void _openModal() {
    _modalHandle ??= ModalScope.open(debugLabel: 'Dialog');
  }

  void _closeModal() {
    _modalHandle?.close();
    _modalHandle = null;
  }

  void _scheduleInitialFocus() {
    // Shown again after a route above it went away: focus still returns to
    // where it was when the dialog first opened.
    _restore ??= FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After the autofocus requests of the dialog's children and the
      // route's own focus request, which the focus manager applies in a
      // microtask.
      scheduleMicrotask(() {
        if (!mounted || !_shown || _scope.hasFocus) return;
        final first = _body.traversalDescendants.firstOrNull;
        (first ?? _boxNode).requestFocus();
      });
    });
  }

  /// Gives focus back to where it was when the dialog opened, unless a
  /// route above the dialog's own holds it now.
  void _restoreFocus() {
    final restore = _restore;
    _restore = null;
    if (_routeVisible != true) return;
    if (restore != null && restore.context != null && restore.canRequestFocus) {
      restore.requestFocus();
    }
  }

  void _close() => widget.onClose?.call();

  Widget _buildBox(BuildContext context, {required bool modal}) {
    final theme = context.ferman;
    final colors = theme.colors;
    final icon = widget.icon;
    final description = widget.description;
    final onClose = widget.onClose;
    final body = widget.child;
    final footerStart = widget.footerStart;
    final buttons = (widget.buttonOrder ?? DialogButtonOrder.current).arrange(
      widget.actions,
      cancel: widget.cancelAction,
      alternate: widget.alternateAction,
    );
    final start = [?footerStart, ...buttons.start];
    final hasFoot = buttons.end.isNotEmpty || start.isNotEmpty;
    final (glyphBackground, glyphColor) = switch (widget.tone) {
      DialogTone.standard => (colors.accentSubtle, colors.textAccent),
      DialogTone.warning => (colors.warningBg, colors.warning),
      DialogTone.danger => (colors.dangerBg, colors.danger),
    };
    final side = theme.space.space5;
    final head = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        Dialog.headTop,
        theme.space.space4,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.space3,
        children: [
          if (icon != null)
            Container(
              width: Dialog.glyphSize,
              height: Dialog.glyphSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: glyphBackground,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
              ),
              child: Icon(icon, size: Dialog.glyphIconSize, color: glyphColor),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(top: theme.space.space1),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space1,
                  children: [
                    Text(
                      widget.title,
                      style: theme.typography.dialogTitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description,
                        style: theme.typography.prose.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: IconName.x,
              label: widget.closeLabel,
              size: IconButtonSize.sm,
              showTooltip: false,
              onPressed: onClose,
            ),
        ],
      ),
    );
    final children = <Widget>[
      head,
      if (body != null)
        Flexible(
          child: Focus(
            focusNode: _body,
            includeSemantics: false,
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: side,
                vertical: theme.space.space4,
              ),
              child: DefaultTextStyle.merge(
                style: theme.typography.prose.copyWith(
                  color: colors.textPrimary,
                ),
                child: body,
              ),
            ),
          ),
        ),
      if (hasFoot)
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            side,
            body == null ? side : theme.space.space1,
            side,
            Dialog.footBottom,
          ),
          child: Row(
            spacing: theme.space.space2,
            children: [
              if (start.isNotEmpty)
                // `.fm-dialog__foot-start { margin-inline-end: auto }`.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: start.length == 1
                        ? start.single
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: theme.space.space2,
                            children: [
                              if (footerStart != null)
                                Flexible(child: footerStart),
                              ...buttons.start,
                            ],
                          ),
                  ),
                )
              else
                const Spacer(),
              ...buttons.end,
            ],
          ),
        ),
    ];
    final maxHeight = modal
        ? MediaQuery.sizeOf(context).height - Dialog.verticalMargin
        : double.infinity;
    Widget box = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: Dialog.widthOf(theme, widget.size),
        minWidth: Dialog.widthOf(theme, widget.size),
        maxHeight: maxHeight < 0 ? 0 : maxHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusLg),
          ),
          boxShadow: theme.elevation.shadowDialog,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.textPrimary),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    box = Semantics(
      container: true,
      scopesRoute: modal,
      namesRoute: true,
      explicitChildNodes: true,
      role: widget.tone == DialogTone.danger
          ? SemanticsRole.alertDialog
          : SemanticsRole.dialog,
      label: widget.title,
      hint: description,
      child: box,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motion.durSlow,
      curve: theme.motion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, Dialog.riseDistance * (1 - t)),
          child: child,
        ),
      ),
      child: box,
    );
  }

  Widget _modalLayer(BuildContext context) {
    final closable = widget.onClose != null;
    final label = widget.closeLabel;
    return PositionedDirectional(
      start: 0,
      end: 0,
      top: 0,
      bottom: 0,
      // Under a route pushed above the dialog's own, the layer keeps its
      // state but is not painted, hit tested or read, and its tickers stop;
      // the navigator gives focus to that route.
      child: Offstage(
        offstage: !_shown,
        child: TickerMode(
          enabled: _shown,
          child: BlockSemantics(
            // The modal layer's own overlay: tooltips, popovers and menus in
            // the dialog open in it, above the box, wherever the dialog sits.
            child: Overlay.wrap(
              child: Scrim(
                onDismiss: widget.onClose,
                dismissLabel: label.isEmpty ? null : label,
                child: FocusScope(
                  node: _scope,
                  child: Shortcuts(
                    shortcuts: {
                      const SingleActivator(LogicalKeyboardKey.tab):
                          const NextFocusIntent(),
                      const SingleActivator(
                        LogicalKeyboardKey.tab,
                        shift: true,
                      ): const PreviousFocusIntent(),
                      if (closable)
                        const SingleActivator(LogicalKeyboardKey.escape):
                            const DismissIntent(),
                    },
                    child: Actions(
                      actions: {
                        NextFocusIntent: NextFocusAction(),
                        PreviousFocusIntent: PreviousFocusAction(),
                        DismissIntent: CallbackAction<DismissIntent>(
                          onInvoke: (_) {
                            _close();
                            return null;
                          },
                        ),
                      },
                      child: FocusTraversalGroup(
                        child: Focus(
                          focusNode: _boxNode,
                          includeSemantics: false,
                          child: _buildBox(context, modal: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) {
      if (!widget.open) return const SizedBox();
      final box = _buildBox(context, modal: false);
      if (widget.onClose == null) return box;
      // The bundle's `onKeyDown` handles Escape on an inline box too; only
      // the Tab trap is modal.
      return CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: box,
      );
    }
    // The root overlay, so the scrim covers the title bar and every
    // nested navigator's screen.
    return OverlayPortal(
      overlayLocation: OverlayChildLocation.rootOverlay,
      controller: _portal,
      overlayChildBuilder: _modalLayer,
      child: const SizedBox.shrink(),
    );
  }
}
