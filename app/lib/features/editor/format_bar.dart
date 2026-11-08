import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gives the open block [style] as one history step, named as the text
/// panel's steps are.
void restyleBlock(BuildContext context, WidgetRef ref, BlockStyle style) {
  final page = ref.read(documentEditorProvider).active?.page ?? 0;
  final format = RegionFormat.forRegion(ref.read(regionProvider).region);
  unawaited(
    ref
        .read(documentEditorProvider.notifier)
        .setBlockStyle(
          style,
          name: AppLocalizations.of(context)
              .editStepStyle(format.integer(page + 1)),
        ),
  );
}

/// The floating bar over a selection in a block being edited (a3-1c):
/// Bold, Italic, Underline and Text colour, then Add link, Highlight and
/// Comment on selection, and Find and replace, disabled until it works.
///
/// The engine styles whole blocks, so the bar changes the whole block, as
/// the text panel does (G141). Font, size and alignment are not on the board
/// and stay in the panel. [onDone] gives the focus back to the block's field.
class FormatBar extends ConsumerStatefulWidget {
  /// The bar for a block styled [info].
  const new({
    required this.info,
    required this.onDone,
    required this.onMark,
    required this.onAddLink,
    super.key,
  });

  /// a3-1c's `top: -50px` less the bar's 32 px height.
  static const double gap = 18;

  /// The block's style as the engine reads it.
  final BlockStyleInfo info;

  /// Called when an action has finished with the focus.
  final VoidCallback onDone;

  /// Highlight or Comment on the selection: commits the typing and marks what
  /// was selected, `composing` waiting for the comment's text.
  final void Function({required bool composing}) onMark;

  /// Add link on the selection (a3-1c, G144).
  final VoidCallback onAddLink;

  @override
  ConsumerState<FormatBar> createState() => _FormatBarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<BlockStyleInfo>('info', info))
      ..add(ObjectFlagProperty<VoidCallback>.has('onDone', onDone))
      ..add(ObjectFlagProperty<VoidCallback>.has('onAddLink', onAddLink))
      ..add(
        ObjectFlagProperty<void Function({required bool composing})>.has(
          'onMark',
          onMark,
        ),
      );
  }
}

class _FormatBarState extends ConsumerState<FormatBar> {
  bool _colourOpen = false;

  void _style(BlockStyle style) {
    restyleBlock(context, ref, style);
    widget.onDone();
  }

  void _openColours({required bool open}) {
    // The popover takes the focus for a while: the block's editor stays open.
    ref.read(documentEditorProvider.notifier).holdEditor(held: open);
    setState(() => _colourOpen = open);
    if (!open) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = widget.info;
    final linkRefusal = ref.watch(linkRefusalProvider);
    final platform = ref.watch(shortcutPlatformProvider);
    final bindings = ref.watch(shortcutBindingsProvider);
    final refusal = ref.watch(commentRefusalProvider)?.call(l10n);
    final mac = platform == ShortcutPlatform.mac;
    List<String> keys(LogicalKeyboardKey key) =>
        KeyBinding(key, meta: mac, control: !mac).caps(platform);
    final bold = info.boldToggle;
    final italic = info.italicToggle;
    final colour = switch (info.colour) {
      final colour? => Color(0xFF000000 | colour),
      null => null,
    };
    return Toolbar(
      variant: ToolbarVariant.floating,
      semanticLabel: l10n.editBarLabel,
      children: [
        IconButton(
          icon: IconName.bold,
          label: l10n.editPanelBold,
          size: IconButtonSize.sm,
          active: info.bold,
          shortcut: keys(LogicalKeyboardKey.keyB),
          disabledReason: bold == null ? l10n.editPanelNoBold : null,
          onPressed: bold == null ? null : () => _style(BlockStyle(font: bold)),
        ),
        IconButton(
          icon: IconName.italic,
          label: l10n.editPanelItalic,
          size: IconButtonSize.sm,
          active: info.italic,
          shortcut: keys(LogicalKeyboardKey.keyI),
          disabledReason: italic == null ? l10n.editPanelNoItalic : null,
          onPressed: italic == null
              ? null
              : () => _style(BlockStyle(font: italic)),
        ),
        IconButton(
          icon: IconName.underline,
          label: l10n.editPanelUnderline,
          size: IconButtonSize.sm,
          disabledReason: l10n.editPanelNoUnderline,
        ),
        ColorPicker(
          value: colour,
          documentColors: [
            for (final colour in info.documentColours)
              Color(0xFF000000 | colour),
          ],
          open: _colourOpen,
          onOpenChanged: (open) => _openColours(open: open),
          documentColorsLabel: l10n.editPanelColoursDocument,
          standardColorsLabel: l10n.editPanelColoursStandard,
          dialogLabel: l10n.editPanelColour,
          onChanged: (picked) {
            _openColours(open: false);
            if (picked == null) return;
            _style(BlockStyle(colour: picked.toARGB32() & 0xFFFFFF));
          },
          triggerBuilder: (context, toggle) => Semantics(
            expanded: _colourOpen,
            value: colour == null ? null : ColorPicker.hexOf(colour),
            child: ToolButton(
              icon: IconName.baseline,
              label: l10n.editPanelColour,
              showLabel: false,
              swatch: colour,
              hasMenu: true,
              onPressed: toggle,
            ),
          ),
        ),
        const ToolbarSeparator(),
        IconButton(
          icon: IconName.link,
          label: l10n.editBarLink,
          size: IconButtonSize.sm,
          shortcut: bindings.caps(ShellCommand.addLink),
          disabledReason: linkRefusal?.call(l10n),
          onPressed: linkRefusal == null ? widget.onAddLink : null,
        ),
        IconButton(
          icon: IconName.highlighter,
          label: l10n.editBarHighlight,
          size: IconButtonSize.sm,
          disabledReason: refusal,
          onPressed: refusal != null
              ? null
              : () => widget.onMark(composing: false),
        ),
        IconButton(
          icon: IconName.messageSquare,
          label: l10n.editBarComment,
          size: IconButtonSize.sm,
          disabledReason: refusal,
          onPressed: refusal != null
              ? null
              : () => widget.onMark(composing: true),
        ),
        IconButton(
          icon: IconName.replace,
          label: l10n.editBarReplace,
          size: IconButtonSize.sm,
          disabledReason: Feature.findAndReplace.disabledReason(context),
        ),
      ],
    );
  }
}
