import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Binds the shortcut table's window-wide keys (`ShortcutScope.window`) for
/// the current mode and system around [child], through [Shortcuts] and
/// [Actions].
///
/// The title bar's content and the screen below it each sit in one, so the
/// keys work wherever focus is. Commands that work in M1 get a handler:
/// Settings when [onOpenSettings] is given and, in the editor, the sidebar
/// and panel toggles and moving between the placeholder documents. On the
/// start screen ([home]) only Settings works. Every other command is
/// disabled, so its keys pass through. The window's own commands (⌘M, ⌘Q,
/// Alt+F4, Ctrl+Q) are the window frame's, on every screen
/// ([WindowCommandScope]).
class ShellCommandScope extends ConsumerWidget {
  /// Binds the shell's keys around [child].
  const new({
    required this.child,
    super.key,
    this.onOpenSettings,
    this.home = false,
  });

  /// The widgets the keys work in.
  final Widget child;

  /// Opens Settings (⌘, or Ctrl+,); null leaves the command disabled.
  final VoidCallback? onOpenSettings;

  /// Whether the start screen shows instead of the editor: the editor's
  /// commands (sidebar, panel, documents) are disabled, and only Settings
  /// works.
  final bool home;

  /// The handlers of the commands that work in M1.
  static Map<ShellCommand, VoidCallback> handlersFor(
    WidgetRef ref, {
    VoidCallback? onOpenSettings,
    bool home = false,
  }) {
    if (home) return {ShellCommand.settings: ?onOpenSettings};
    final documents = ref.read(shellDocumentsProvider.notifier);
    final count = ref.read(shellDocumentsProvider).documents.length;
    final panels = ref.read(shellPanelsProvider);
    const jumps = [
      ShellCommand.document1,
      ShellCommand.document2,
      ShellCommand.document3,
      ShellCommand.document4,
      ShellCommand.document5,
      ShellCommand.document6,
      ShellCommand.document7,
      ShellCommand.document8,
      ShellCommand.document9,
    ];
    return {
      // Like the mode bar's toggles: a panel that stepped aside in a narrow
      // window comes back; one that cannot fit even alone leaves its keys
      // unbound (G21).
      if (panels.sidebarAvailable)
        ShellCommand.toggleSidebar: () =>
            toggleShellSide(ref, ShellSide.sidebar),
      if (panels.panelAvailable)
        ShellCommand.togglePanel: () => toggleShellSide(ref, ShellSide.panel),
      ShellCommand.settings: ?onOpenSettings,
      if (count > 1) ShellCommand.nextDocument: documents.activateNext,
      for (var i = 0; i < jumps.length && i < count; i++)
        jumps[i]: () => documents.activate(i),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(shortcutPlatformProvider);
    final mode = ref.watch(shellModeProvider);
    // Rebuild the handlers when the documents or the panels' room change.
    if (!home) {
      ref
        ..watch(shellDocumentsProvider)
        ..watch(shellPanelsProvider);
    }
    return Actions(
      actions: {
        ShellCommandIntent: ShellCommandAction(
          handlersFor(ref, onOpenSettings: onOpenSettings, home: home),
        ),
      },
      child: Shortcuts(
        shortcuts: ShellCommand.shortcutsFor(platform, mode),
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        ObjectFlagProperty<VoidCallback>.has('onOpenSettings', onOpenSettings),
      )
      ..add(FlagProperty('home', value: home, ifTrue: 'home'));
  }
}

/// Binds the window's own commands from the shortcut table
/// ([ShellCommand.windowCommands]: ⌘M and ⌘Q on macOS, Alt+F4 on Windows
/// and Linux, Ctrl+Q on Linux) around [child], for every screen the window
/// frame holds: the start screen, first run, Settings and the editor.
///
/// Minimize minimizes [window]; close and quit close it, as the caption
/// buttons do (the window asks about unsaved documents from M3 on, G40).
/// Nothing is bound where the system draws the window
/// ([DesktopWindow.platform] null). The keys follow the shortcut table's
/// conventions for the system (`shortcutPlatformProvider`).
class WindowCommandScope extends ConsumerWidget {
  /// Binds [window]'s commands around [child].
  const new({required this.window, required this.child, super.key});

  /// The window the commands act on.
  final DesktopWindow window;

  /// The screens the keys work in.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (window.platform == null) return child;
    final platform = ref.watch(shortcutPlatformProvider);
    final handlers = <ShellCommand, VoidCallback>{
      ShellCommand.minimizeWindow: window.minimize,
      ShellCommand.closeWindow: window.close,
      ShellCommand.quit: window.close,
    };
    return Actions(
      actions: {_WindowCommandIntent: _WindowCommandAction(handlers)},
      child: Shortcuts(
        shortcuts: {
          for (final command in ShellCommand.windowCommands)
            for (final binding in command.bindingsFor(platform))
              binding.activator: _WindowCommandIntent(command),
        },
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DesktopWindow>('window', window));
  }
}

/// A window command's keys. A type of its own, so the editor's
/// [ShellCommandAction] below never answers for it.
class _WindowCommandIntent extends Intent {
  const new(this.command);

  final ShellCommand command;
}

class _WindowCommandAction extends Action<_WindowCommandIntent> {
  new(this.handlers);

  final Map<ShellCommand, VoidCallback> handlers;

  @override
  bool isEnabled(_WindowCommandIntent intent) =>
      handlers.containsKey(intent.command);

  @override
  Object? invoke(_WindowCommandIntent intent) {
    handlers[intent.command]?.call();
    return null;
  }
}
