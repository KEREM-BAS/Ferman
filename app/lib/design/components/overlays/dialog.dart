import 'dart:async';
import 'dart:ui' show SemanticsRole;

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
/// secondary text, and [closeButton] at the end. [child] is the scrolling
/// body in prose type (16 px by 20 px of padding); the foot ends the box
/// with [actions] lined up at the end, 8 px apart, and [footerStart] at the
/// start. Footer actions come in the order the platform expects (Cancel on
/// the left on Windows and Linux, Q12): the screen orders them. The box
/// rises in over `--dur-slow`.
///
/// **Modal.** Unless [inline], a dialog is shown while [open] in the
/// nearest [Overlay] (through an [OverlayPortal]; no Material route),
/// centred over a [Scrim], wherever it sits in the tree. It is modal:
/// screen readers see only the dialog, focus is trapped inside it (Tab and
/// Shift+Tab cycle), and focus goes on open to a child that asks for
/// `autofocus` (the bundle's `data-autofocus`), else to the first focusable
/// control in the body, else to the dialog itself (which shows no ring),
/// and returns on close to where it was. With [onClose], Escape and a
/// pointer down on the scrim call it; [closeLabel] names the scrim as a
/// dismiss target. [inline] draws the box in place, without scrim,
/// modality or trap (boards and the gallery).
///
/// **Slots.** The close button ([closeButton], an `IconButton` with `x`,
/// [closeLabel] and no tooltip, calling [onClose]) and the footer buttons
/// are widgets the screen composes: the buttons belong to the core group.
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
    this.footerStart,
    this.onClose,
    this.closeLabel = '',
    this.closeButton,
  });

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

  /// The footer buttons, lined up at the end in this order.
  final List<Widget> actions;

  /// A widget at the start of the footer (a checkbox, a link).
  final Widget? footerStart;

  /// Called on Escape and on a pointer down on the scrim; null makes the
  /// dialog wait for an action.
  final VoidCallback? onClose;

  /// The accessible name of the scrim as a dismiss target, and the label
  /// the screen gives the close button ("Close"); empty for none.
  final String closeLabel;

  /// The close button at the end of the head (an `IconButton` with `x`
  /// calling [onClose]); null shows none. Not a design-system prop.
  final Widget? closeButton;

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

  bool get _modal => widget.open && !widget.inline;

  @override
  void initState() {
    super.initState();
    if (_modal) {
      // Not attached yet, so this only records that the portal starts
      // shown.
      _portal.show();
      _scheduleInitialFocus();
    }
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
    _restoreFocus();
    _scope.dispose();
    _boxNode.dispose();
    _body.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    if (_modal && !_portal.isShowing) {
      _portal.show();
      _scheduleInitialFocus();
    } else if (!_modal && _portal.isShowing) {
      _portal.hide();
      _restoreFocus();
    }
  }

  void _scheduleInitialFocus() {
    _restore = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After the autofocus requests of the dialog's children, which the
      // focus manager applies in a microtask.
      scheduleMicrotask(() {
        if (!mounted || !_modal || _scope.hasFocus) return;
        final first = _body.traversalDescendants.firstOrNull;
        (first ?? _boxNode).requestFocus();
      });
    });
  }

  void _restoreFocus() {
    final restore = _restore;
    _restore = null;
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
    final closeButton = widget.closeButton;
    final body = widget.child;
    final footerStart = widget.footerStart;
    final hasFoot = widget.actions.isNotEmpty || footerStart != null;
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
          ?closeButton,
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
              if (footerStart != null)
                // `.fm-dialog__foot-start { margin-inline-end: auto }`.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: footerStart,
                  ),
                )
              else
                const Spacer(),
              ...widget.actions,
            ],
          ),
        )
      else if (body == null)
        const SizedBox(height: Dialog.footBottom),
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
      child: BlockSemantics(
        child: Scrim(
          onDismiss: widget.onClose,
          dismissLabel: label.isEmpty ? null : label,
          child: FocusScope(
            node: _scope,
            child: Shortcuts(
              shortcuts: {
                const SingleActivator(LogicalKeyboardKey.tab):
                    const NextFocusIntent(),
                const SingleActivator(LogicalKeyboardKey.tab, shift: true):
                    const PreviousFocusIntent(),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) {
      return widget.open ? _buildBox(context, modal: false) : const SizedBox();
    }
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _modalLayer,
      child: const SizedBox.shrink(),
    );
  }
}
