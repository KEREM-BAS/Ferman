import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/signatures/add_signature_dialog.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:ferman/features/signatures/signature_preview.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/account_name.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The key that places the first saved signature while the Sign menu is open
/// (a5-3d's `kSig`, decision 24).
const KeyBinding firstSignatureKey = KeyBinding(
  LogicalKeyboardKey.keyS,
  alt: true,
);

const String _addId = 'add';
const String _manageId = 'manage';

/// The name a typed signature starts with: the commenter name, else the
/// account's.
String yourNameOf(WidgetRef ref) =>
    ref.read(settingsProvider).commenterName ?? accountName();

/// The saved signatures, then the saved initials.
(List<SavedSignature>, List<SavedSignature>) _groups(
  List<SavedSignature> saved,
) => (
  [
    for (final each in saved)
      if (!each.initials) each,
  ],
  [
    for (final each in saved)
      if (each.initials) each,
  ],
);

/// A saved signature's name in a plain menu.
String _labelOf(SavedSignature signature, AppLocalizations l10n) =>
    switch (signature.ink) {
      TypedInk(:final text) => text,
      DrawnInk() => l10n.signDrawn,
      ImageInk() => l10n.signPadImage,
    };

/// Initials (the Fill & Sign row's button): places the first saved initials,
/// or opens a5-3's dialog on Initials when there are none.
void startInitials(WidgetRef ref) {
  final initials = _groups(ref.read(savedSignaturesProvider).value ?? []).$2;
  if (initials.isEmpty) {
    showAddSignatureDialog(ref, yourName: yourNameOf(ref), initials: true);
  } else {
    ref.read(signaturePlacementProvider.notifier).choose(initials.first);
  }
}

/// The Sign menu as a submenu of the overflow menu (B093), which no board
/// draws: the saved ones by name, then Add and Manage.
List<MenuItem> signMenuItems(
  BuildContext context,
  AppLocalizations l10n,
  List<SavedSignature> saved,
) {
  final casing = LocaleCasing.of(context);
  final (signatures, initials) = _groups(saved);
  return [
    for (final (title, group) in [
      (l10n.signMenuSignatures, signatures),
      (l10n.signKindInitials, initials),
    ])
      if (group.isNotEmpty) ...[
        MenuItem.section(casing.upper(title)),
        for (final each in group)
          MenuItem(id: each.name, label: _labelOf(each, l10n)),
      ],
    if (saved.isNotEmpty) const MenuItem.divider(),
    MenuItem(
      id: _addId,
      label: saved.isEmpty ? l10n.signMenuCreate : l10n.signMenuAdd,
      icon: IconName.plus,
    ),
    MenuItem(
      id: _manageId,
      label: l10n.signMenuManage,
      icon: IconName.settings,
    ),
  ];
}

/// Manage saved signatures…: Settings › Signatures and certificates
/// (a11-1e).
void manageSignatures(WidgetRef ref) => unawaited(
  ref
      .read(routerProvider)
      .push(Routes.settingsPane(SettingsPane.signatures.path)),
);

/// Does what the Sign submenu's [item] says.
void signMenuChosen(WidgetRef ref, MenuItem item) {
  if (item.id == _addId) {
    showAddSignatureDialog(ref, yourName: yourNameOf(ref));
    return;
  }
  if (item.id == _manageId) {
    manageSignatures(ref);
    return;
  }
  final saved = ref.read(savedSignaturesProvider).value ?? [];
  final chosen = saved.where((each) => each.name == item.id).firstOrNull;
  if (chosen != null) {
    ref.read(signaturePlacementProvider.notifier).choose(chosen);
  }
}

/// a5-3d's Sign button and its menu.
class SignTool extends ConsumerStatefulWidget {
  /// The button, [live] when it can sign; [disabledReason] says why not.
  const new({required this.live, this.disabledReason, super.key});

  /// Whether the open document can take a signature.
  final bool live;

  /// Why it cannot, when it says.
  final String? disabledReason;

  @override
  ConsumerState<SignTool> createState() => _SignToolState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('live', value: live, ifTrue: 'live'))
      ..add(StringProperty('disabledReason', disabledReason));
  }
}

class _SignToolState extends ConsumerState<SignTool> {
  bool _open = false;

  void _close() => setState(() => _open = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = widget.live;
    return Popover(
      open: _open && live,
      surface: false,
      onDismiss: _close,
      anchor: ToolButton(
        icon: IconName.signature,
        label: l10n.shellToolSign,
        hasMenu: true,
        disabled: !live,
        disabledReason: widget.disabledReason,
        onPressed: live ? () => setState(() => _open = !_open) : null,
      ),
      child: SignMenu(onClose: _close),
    );
  }
}

/// a5-3d's Sign menu: SIGNATURES and INITIALS with real previews, then Add
/// signature… and Manage saved signatures…. With nothing saved it offers
/// Create signature… (G47). A saved one's own menu deletes it, by the
/// secondary button or the menu key; ⌥S places the first signature while it is
/// open (decision 24).
class SignMenu extends ConsumerStatefulWidget {
  /// The menu; [onClose] closes it.
  const new({required this.onClose, super.key});

  /// The menu's width (`width: 280px`).
  static const double width = 280;

  /// A signature row's height (`height: 48px`).
  static const double signatureHeight = 48;

  /// An initials row's height (`height: 40px`).
  static const double initialsHeight = 40;

  /// An action row's height (`height: 30px`).
  static const double actionHeight = 30;

  /// A preview's size in a signature row (`26px`).
  static const double previewSize = 26;

  /// The gap in a row (`gap: 10px`).
  static const double rowGap = 10;

  /// Called to close it.
  final VoidCallback onClose;

  @override
  ConsumerState<SignMenu> createState() => _SignMenuState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<VoidCallback>.has('onClose', onClose));
  }
}

class _SignMenuState extends ConsumerState<SignMenu> {
  /// The first row, which takes focus when the menu opens.
  final FocusNode _first = FocusNode(debugLabel: 'SignMenu first');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _first.requestFocus();
    });
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  void _choose(WidgetRef ref, SavedSignature signature) {
    widget.onClose();
    ref.read(signaturePlacementProvider.notifier).choose(signature);
  }

  void _showMenu(
    BuildContext context,
    WidgetRef ref,
    SavedSignature signature,
    Offset position,
  ) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final group = Popover.groupOf(context);
    final saved = ref.read(savedSignaturesProvider.notifier);
    ContextMenuController().show(
      context: context,
      contextMenuBuilder: (context) => CustomSingleChildLayout(
        delegate: DesktopTextSelectionToolbarLayoutDelegate(anchor: position),
        child: Directionality(
          textDirection: direction,
          child: TapRegion(
            groupId: group,
            child: Menu(
              semanticLabel: _labelOf(signature, l10n),
              autofocus: true,
              items: [
                MenuItem(
                  id: 'delete',
                  label: l10n.signDelete,
                  icon: IconName.trash2,
                  danger: true,
                ),
              ],
              onClose: ContextMenuController.removeAny,
              onSelected: (_) {
                ContextMenuController.removeAny();
                unawaited(saved.remove(signature));
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    var focused = false;
    FocusNode? first() {
      if (focused) return null;
      focused = true;
      return _first;
    }

    final keys = ref.watch(shortcutBindingsProvider);
    final saved = ref.watch(savedSignaturesProvider).value ?? const [];
    final chosen = ref.watch(signaturePlacementProvider);
    final (signatures, initials) = _groups(saved);
    final heading = theme.typography.label.copyWith(
      color: theme.colors.textTertiary,
    );
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );
    final border = BorderSide(color: theme.colors.borderSubtle);
    Widget title(String text, {bool line = false}) => Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        theme.space.space2,
        theme.space.space1_5,
        theme.space.space2,
        theme.space.space1,
      ),
      margin: EdgeInsetsDirectional.only(top: line ? theme.space.space1 : 0),
      decoration: line ? BoxDecoration(border: Border(top: border)) : null,
      child: Text(casing.upper(text), style: heading),
    );
    Widget row(SavedSignature signature, double height, {Widget? end}) =>
        GestureDetector(
          onSecondaryTapUp: (details) =>
              _showMenu(context, ref, signature, details.globalPosition),
          child: _Row(
            height: height,
            focusNode: first(),
            selected: signature == chosen,
            semanticLabel: _labelOf(signature, l10n),
            onPressed: () => _choose(ref, signature),
            onMenu: (position) => _showMenu(context, ref, signature, position),
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SignaturePreview(
                    signature: signature,
                    height: SignMenu.previewSize,
                  ),
                ),
              ),
              ?end,
            ],
          ),
        );
    Widget? captionOf(SavedSignature signature) => switch (signature.ink) {
      TypedInk() => null,
      DrawnInk() => Text(l10n.signDrawn, style: caption),
      ImageInk() => Text(l10n.signPadImage, style: caption),
    };
    final icon = theme.colors.iconSecondary;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          node.nextFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          node.previousFocus();
          return KeyEventResult.handled;
        }
        if (signatures.isNotEmpty &&
            firstSignatureKey.activator.accepts(
              event,
              HardwareKeyboard.instance,
            )) {
          _choose(ref, signatures.first);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.signMenuLabel,
        child: Container(
          width: SignMenu.width,
          padding: EdgeInsetsDirectional.all(theme.space.space1),
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(theme.radius.radiusMd),
            boxShadow: theme.elevation.shadowPopover,
          ),
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (signatures.isNotEmpty) ...[
                  title(l10n.signMenuSignatures),
                  for (final (index, signature) in signatures.indexed)
                    row(
                      signature,
                      SignMenu.signatureHeight,
                      end: index == 0
                          ? Kbd(
                              firstSignatureKey.caps(keys.platform),
                              tone: KbdTone.plain,
                            )
                          : captionOf(signature),
                    ),
                ],
                if (initials.isNotEmpty) ...[
                  title(l10n.signKindInitials, line: signatures.isNotEmpty),
                  for (final signature in initials)
                    row(
                      signature,
                      SignMenu.initialsHeight,
                      end: captionOf(signature),
                    ),
                ],
                if (saved.isNotEmpty)
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: theme.space.space1,
                    ),
                    child: Container(
                      height: theme.border.borderWidth,
                      color: theme.colors.borderSubtle,
                    ),
                  ),
                _Row(
                  height: SignMenu.actionHeight,
                  focusNode: first(),
                  semanticLabel: saved.isEmpty
                      ? l10n.signMenuCreate
                      : l10n.signMenuAdd,
                  onPressed: () {
                    widget.onClose();
                    showAddSignatureDialog(ref, yourName: yourNameOf(ref));
                  },
                  children: [
                    Icon(
                      IconName.plus,
                      size: theme.density.iconMd,
                      color: icon,
                    ),
                    Text(
                      saved.isEmpty ? l10n.signMenuCreate : l10n.signMenuAdd,
                    ),
                  ],
                ),
                _Row(
                  height: SignMenu.actionHeight,
                  semanticLabel: l10n.signMenuManage,
                  onPressed: () {
                    widget.onClose();
                    manageSignatures(ref);
                  },
                  children: [
                    Icon(
                      IconName.settings,
                      size: theme.density.iconMd,
                      color: icon,
                    ),
                    Text(l10n.signMenuManage),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the Sign menu: `padding: 0 8px`, `--radius-sm`, tinted when
/// hovered, focused or chosen.
class _Row extends StatelessWidget {
  const new({
    required this.height,
    required this.semanticLabel,
    required this.children,
    this.onPressed,
    this.onMenu,
    this.selected = false,
    this.focusNode,
  });

  final double height;
  final String semanticLabel;
  final List<Widget> children;
  final VoidCallback? onPressed;
  final ValueChanged<Offset>? onMenu;
  final bool selected;
  final FocusNode? focusNode;

  KeyEventResult _onKey(BuildContext context, KeyEvent event) {
    final onMenu = this.onMenu;
    if (onMenu == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final asked =
        event.logicalKey == LogicalKeyboardKey.contextMenu ||
        (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed);
    final box = context.findRenderObject();
    if (!asked || box is! RenderBox) return KeyEventResult.ignored;
    onMenu(box.localToGlobal(box.size.center(Offset.zero)));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final row = FermanInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      selected: selected,
      semanticLabel: semanticLabel,
      builder: (context, states, child) => Container(
        height: height,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? theme.colors.surfaceSelectedStrong
              : states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
              ? theme.colors.surfaceHover
              : null,
          borderRadius: BorderRadius.circular(theme.radius.radiusSm),
        ),
        child: child,
      ),
      child: DefaultTextStyle.merge(
        style: theme.typography.body,
        child: Row(spacing: SignMenu.rowGap, children: children),
      ),
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKey(context, event),
      child: row,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('height', height))
      ..add(StringProperty('semanticLabel', semanticLabel))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'));
  }
}
