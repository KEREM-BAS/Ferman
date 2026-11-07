import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Keyboard shortcuts pane of Settings, board a11-1j (B076).
///
/// A search field that matches names, or the keys pressed into it, and the
/// preset menu (Ferman's own; Like Acrobat and Like Preview are disabled,
/// [Feature.shortcutPresets]); then every command but the window's own,
/// with its keys (`shortcutBindingsProvider`).
///
/// Clicking a command's keys records new ones: the row says "Press new
/// shortcut…" until a combination is pressed. Free keys apply at once and
/// are stored (`AppSettings.shortcuts`). Keys another command has in a
/// shared mode show a1-1j's warning: Enter gives them to this command,
/// which leaves the other without them, possibly with none (M4 decision
/// 33); Esc keeps the keys it had. Keys of the system and of focus
/// ([ShortcutBindings.reserved]) are refused with a note. A changed command
/// has a button that restores its default keys.
class ShortcutsPane extends ConsumerStatefulWidget {
  /// The pane.
  const new({super.key});

  /// a11-1j: the preset menu's width.
  static const double presetWidth = 200;

  /// a11-1j: the keys column's width.
  static const double keysWidth = 220;

  /// a11-1j: a row's least height.
  static const double rowMinHeight = 38;

  /// a11-1j: the recording outline's width (`0 0 0 1.5px`).
  static const double recordingOutline = 1.5;

  @override
  ConsumerState<ShortcutsPane> createState() => _ShortcutsPaneState();
}

class _ShortcutsPaneState extends ConsumerState<ShortcutsPane> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _recorder = FocusNode(debugLabel: 'ShortcutsPane recorder');

  /// The command whose keys are being recorded.
  ShellCommand? _recording;

  /// Keys pressed that another command has, waiting for Enter or Esc.
  KeyBinding? _pending;

  /// The note under the recording command: the keys are taken or reserved.
  String? _note;

  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };

  @override
  void dispose() {
    _search.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// The combination of [key] with the modifiers held now.
  static KeyBinding _pressed(LogicalKeyboardKey key) {
    final keyboard = HardwareKeyboard.instance;
    return KeyBinding(
      key,
      meta: keyboard.isMetaPressed,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
    );
  }

  void _record(ShellCommand command) {
    setState(() {
      _recording = command;
      _pending = null;
      _note = null;
    });
    _recorder.requestFocus();
  }

  void _stop() {
    setState(() {
      _recording = null;
      _pending = null;
      _note = null;
    });
  }

  void _store(ShortcutBindings bindings) {
    _stop();
    changeSetting(
      ref,
      (settings) =>
          settings.copyWith(shortcuts: bindings.toSettings(settings.shortcuts)),
    ).ignore();
  }

  KeyEventResult _onRecorderKey(FocusNode node, KeyEvent event) {
    final command = _recording;
    if (command == null || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_modifiers.contains(key)) return KeyEventResult.handled;
    final keys = ref.read(shortcutBindingsProvider);
    final binding = _pressed(key);
    final pending = _pending;
    if (pending != null &&
        binding == const KeyBinding(LogicalKeyboardKey.enter)) {
      _store(keys.rebind(command, pending));
      return KeyEventResult.handled;
    }
    if (binding == const KeyBinding(LogicalKeyboardKey.escape)) {
      _stop();
      return KeyEventResult.handled;
    }
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.read(regionProvider).region);
    final caps = binding.caps(keys.platform).join();
    if (keys.reserved(command, binding)) {
      setState(() {
        _pending = null;
        _note = l10n.shortcutsReserved(caps);
      });
      return KeyEventResult.handled;
    }
    final holders = keys.holders(command, binding);
    if (holders.isEmpty) {
      _store(keys.rebind(command, binding));
      return KeyEventResult.handled;
    }
    // Every command Enter takes the keys from, each in the message's quotes.
    final name = [
      for (final holder in holders) l10n.commandLabel(holder, format),
    ].join('”, “');
    final current = keys.caps(command);
    setState(() {
      _pending = binding;
      _note = current == null
          ? l10n.shortcutsTakenNone(caps, name)
          : l10n.shortcutsTaken(caps, name, current.join());
    });
    return KeyEventResult.handled;
  }

  /// Keys with ⌘, Ctrl or Alt pressed in the search field search by keys.
  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _modifiers.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    final binding = _pressed(event.logicalKey);
    if (binding.isPlain) return KeyEventResult.ignored;
    final keys = ref.read(shortcutBindingsProvider);
    final text = binding.caps(keys.platform).join();
    _search.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final keys = ref.watch(shortcutBindingsProvider);
    final query = casing.lower(_search.text.trim()).replaceAll(' ', '');
    final commands = [
      for (final command in ShellCommand.values)
        if (!ShellCommand.windowCommands.contains(command) &&
            (query.isEmpty ||
                casing
                    .lower(l10n.commandLabel(command, format))
                    .contains(query) ||
                casing
                    .lower((keys.caps(command) ?? const []).join())
                    .contains(query)))
          command,
    ];
    final border = BorderSide(
      color: colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));

    Widget row(ShellCommand command, {required bool last}) {
      final label = l10n.commandLabel(command, format);
      final recording = command == _recording;
      final caps = keys.caps(command);
      final note = recording ? _note : null;
      final Widget shown;
      if (recording) {
        final pressed = _pending?.caps(keys.platform) ?? caps;
        shown = Container(
          height: theme.density.controlHSm,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space2_5,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: colors.accent,
              width: ShortcutsPane.recordingOutline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space.space2,
            children: [
              Flexible(
                child: Text(
                  l10n.shortcutsRecording,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: colors.textAccent,
                  ),
                ),
              ),
              if (pressed != null) Kbd(pressed),
            ],
          ),
        );
      } else {
        shown = caps == null
            ? Text(
                l10n.shortcutsNone,
                style: theme.typography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              )
            : Kbd(caps);
      }
      return Container(
        constraints: const BoxConstraints(
          minHeight: ShortcutsPane.rowMinHeight,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space3 + theme.space.space0_5,
          vertical: theme.space.space1,
        ),
        decoration: BoxDecoration(
          color: recording ? colors.surfaceSelected : null,
          border: last ? null : Border(bottom: border),
        ),
        child: Row(
          spacing: theme.space.space3,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.typography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (note != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        note,
                        style: theme.typography.caption.copyWith(
                          color: colors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: ShortcutsPane.keysWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: theme.space.space1,
                children: [
                  if (keys.changed(command) && !recording)
                    IconButton(
                      icon: IconName.undo2,
                      label: l10n.shortcutsReset,
                      size: IconButtonSize.sm,
                      onPressed: () => _store(keys.reset(command)),
                    ),
                  Flexible(
                    child: FermanInteractive(
                      onPressed: recording ? _stop : () => _record(command),
                      semanticLabel: l10n.shortcutsChange(label),
                      builder: (context, states, _) => FocusRing(
                        visible: states.contains(WidgetState.focused),
                        borderRadius: radius,
                        child: shown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Focus(
      focusNode: _recorder,
      onKeyEvent: _onRecorderKey,
      skipTraversal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          Row(
            spacing: theme.space.space2_5,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: _onSearchKey,
                  canRequestFocus: false,
                  skipTraversal: true,
                  child: TextField(
                    size: FieldSize.sm,
                    icon: IconName.search,
                    controller: _search,
                    placeholder: l10n.shortcutsPaneSearch,
                    semanticLabel: l10n.shortcutsPaneSearch,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              SizedBox(
                width: ShortcutsPane.presetWidth,
                child: Select<String>(
                  size: FieldSize.sm,
                  semanticLabel: l10n.shortcutsPreset,
                  value: 'ferman',
                  onChanged: (_) {},
                  options: [
                    SelectOption(
                      value: 'ferman',
                      label: l10n.shortcutsPresetFerman,
                    ),
                    SelectOption(
                      value: 'acrobat',
                      label: l10n.shortcutsPresetAcrobat,
                      disabled: true,
                      disabledReason: Feature.shortcutPresets.disabledReason(
                        context,
                      ),
                    ),
                    SelectOption(
                      value: 'preview',
                      label: l10n.shortcutsPresetPreview,
                      disabled: true,
                      disabledReason: Feature.shortcutPresets.disabledReason(
                        context,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (commands.isEmpty)
            Text(
              l10n.shortcutsNoMatch(_search.text.trim()),
              style: theme.typography.body.copyWith(
                color: colors.textSecondary,
              ),
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.fromBorderSide(border),
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, command) in commands.indexed)
                    row(command, last: i == commands.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ShellCommand>('recording', _recording));
  }
}
