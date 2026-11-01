import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The context menu of a text field (B017, G80): the design-system [Menu]
/// at the pointer with Cut, Copy and Paste, then Select all, each with the
/// platform's keys. An item the field cannot do now (Copy without a
/// selection, Cut in a read-only field) shows disabled, as native menus
/// do. Focus stays in the field: the pointer chooses, Escape closes, and
/// the keys work as they always do. Pass it as an `EditableText`'s
/// `contextMenuBuilder`, with no `selectionControls`.
Widget fieldContextMenu(BuildContext context, EditableTextState field) {
  final l10n = AppLocalizations.of(context);
  final mac =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  List<String> keys(String key) => [if (mac) '⌘' else 'Ctrl', key];
  final available = {
    for (final item in field.contextMenuButtonItems) item.type: item.onPressed,
  };
  MenuItem item(ContextMenuButtonType type, String label, String key) =>
      MenuItem(
        id: type.name,
        label: label,
        shortcut: keys(key),
        disabled: available[type] == null,
      );
  return CustomSingleChildLayout(
    delegate: DesktopTextSelectionToolbarLayoutDelegate(
      anchor: field.contextMenuAnchors.primaryAnchor,
    ),
    // Focus stays in the field, which hides the menu when it loses focus;
    // Escape closes it from there.
    child: _EscapeCloses(
      onEscape: field.hideToolbar,
      child: Menu(
        semanticLabel: l10n.fieldContextMenu,
        items: [
          item(ContextMenuButtonType.cut, l10n.fieldCut, 'X'),
          item(ContextMenuButtonType.copy, l10n.fieldCopy, 'C'),
          item(ContextMenuButtonType.paste, l10n.fieldPaste, 'V'),
          const MenuItem.divider(),
          item(ContextMenuButtonType.selectAll, l10n.fieldSelectAll, 'A'),
        ],
        onClose: field.hideToolbar,
        onSelected: (chosen) {
          final type = ContextMenuButtonType.values.byName(chosen.id ?? '');
          available[type]?.call();
          ContextMenuController.removeAny();
        },
      ),
    ),
  );
}

/// Calls [onEscape] on Escape while it is shown, wherever focus is.
class _EscapeCloses extends StatefulWidget {
  const new({required this.onEscape, required this.child});

  final VoidCallback onEscape;
  final Widget child;

  @override
  State<_EscapeCloses> createState() => _EscapeClosesState();
}

class _EscapeClosesState extends State<_EscapeCloses> {
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    widget.onEscape();
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
