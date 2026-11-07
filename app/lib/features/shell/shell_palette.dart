import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/tools/compress_panel.dart';
import 'package:ferman/features/tools/version_history.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The command palette (a11-2, B030): ⌘K or Ctrl+K and the title bar's
/// Search, on the start screen and in the editor, shown through
/// `organizeDialogProvider`.
///
/// One field for four groups: **Commands**, every command of the shortcut
/// table that works now (its handler from [ShellCommandScope.handlersFor])
/// and those a later version brings ([unfinishedCommands], disabled with
/// the reason), with Background tasks (M4 decision 30) and Optimize and
/// clean (B030) in the editor; **Pages**, the outline's entries and the page
/// a number names; **Recent files**; and **Settings**, its panes. Matching
/// folds case with the UI language's rules (`LocaleCasing`: "imza" finds
/// "İmzalar"). With no match, Enter closes the palette and searches the
/// document's text through the find bar, whose search folds dotted and
/// dotless i too (G61).
class ShellPalette extends ConsumerStatefulWidget {
  /// The palette over the start screen ([home]) or the editor.
  const new({super.key, this.home = false, this.onOpenSettings});

  /// Whether the start screen is below: only its commands work.
  final bool home;

  /// Opens Settings; null leaves the command out.
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<ShellPalette> createState() => _ShellPaletteState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('home', value: home, ifTrue: 'home'))
      ..add(
        ObjectFlagProperty<VoidCallback>.has('onOpenSettings', onOpenSettings),
      );
  }
}

class _ShellPaletteState extends ConsumerState<ShellPalette> {
  String _query = '';

  /// What each row runs, by its id.
  final Map<String, VoidCallback> _actions = {};

  void _close() => ref.read(organizeDialogProvider.notifier).close();

  void _run(CommandItem item) {
    final action = _actions[item.id];
    // Closed first, so a command that opens a dialog of its own replaces
    // the palette rather than being replaced by the close.
    _close();
    action?.call();
  }

  void _searchDocument(String query) {
    _close();
    ref.read(findProvider.notifier)
      ..open()
      ..setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final keys = ref.watch(shortcutBindingsProvider);
    final document = widget.home ? null : ref.watch(openDocumentProvider);
    final handlers = ShellCommandScope.handlersFor(
      ref,
      onOpenSettings: widget.onOpenSettings,
      onOpenFiles: openFiles(context, ref),
      home: widget.home,
    );
    _actions.clear();
    CommandItem item(
      String id,
      String label,
      VoidCallback? action, {
      IconName icon = IconName.command,
      String? hint,
      List<String>? shortcut,
      String? disabledReason,
    }) {
      if (action != null) _actions[id] = action;
      return CommandItem(
        id: id,
        label: label,
        icon: icon,
        hint: hint,
        shortcut: shortcut,
        keywords: hint,
        disabledReason: disabledReason,
      );
    }

    final commands = [
      for (final command in ShellCommand.values)
        if (!ShellCommand.windowCommands.contains(command) &&
            !documentJumps.contains(command) &&
            command != ShellCommand.commandPalette)
          if (handlers[command] case final run?)
            _commandItem(item, command, run, l10n, format, keys)
          else if (unfinishedCommands[command] case final feature?)
            _commandItem(
              item,
              command,
              null,
              l10n,
              format,
              keys,
              disabledReason: feature.disabledReason(context),
            ),
      if (!widget.home) ...[
        item(
          'tasks',
          l10n.tasksTitle,
          ref.read(backgroundJobsProvider.notifier).openDrawer,
          icon: IconName.listChecks,
        ),
        if (document != null)
          item(
            'optimize',
            l10n.optimizeAction,
            () => unawaited(
              ref.read(documentSaverProvider.notifier).optimizeAndClean(),
            ),
            icon: IconName.sparkles,
          ),
        if (document != null) ...[
          item(
            'compress',
            l10n.shellToolCompress,
            () => showCompress(ref),
            icon: IconName.minimize2,
            hint: l10n.shellModeTools,
          ),
          item(
            'versions',
            l10n.shellToolVersionHistory,
            () => showVersionHistory(ref),
            icon: IconName.history,
            hint: l10n.shellModeTools,
          ),
        ],
      ],
    ];

    final pages = <CommandItem>[];
    if (document != null) {
      final viewer = ref.read(viewerProvider.notifier);
      String pageName(int index) =>
          document.pages[index].label ?? format.integer(index + 1);
      for (final (i, entry) in document.outline.indexed) {
        if (entry.page case final page? when page < document.pages.length) {
          pages.add(
            item(
              'outline-$i',
              '${l10n.sidebarPage(pageName(page))} · ${entry.title}',
              () => viewer.goToPage(page),
              icon: IconName.fileText,
            ),
          );
        }
      }
      // A number or a page label names a page, outline or not.
      final query = _query.trim();
      for (var i = 0; i < document.pages.length; i++) {
        if (query.isNotEmpty &&
            (pageName(i) == query || int.tryParse(query) == i + 1)) {
          pages.add(
            item(
              'page-$i',
              l10n.sidebarPage(pageName(i)),
              () => viewer.goToPage(i),
              icon: IconName.fileText,
              hint: query,
            ),
          );
          break;
        }
      }
    }

    final recent = [
      for (final file in ref.watch(recentFilesProvider))
        item(
          'recent-${file.path}',
          file.name,
          () => unawaited(
            ref.read(documentOpenerProvider.notifier).openRecent(file),
          ),
          icon: IconName.fileText,
          hint: _folderOf(file.path),
        ),
    ];

    final settings = [
      for (final pane in SettingsPane.values)
        item(
          'settings-${pane.path}',
          pane.label(l10n),
          pane.available
              ? () => unawaited(
                  context.push<void>(Routes.settingsPane(pane.path)),
                )
              : null,
          icon: pane.icon,
          hint: l10n.settingsTitle,
          disabledReason: pane.feature?.disabledReason(context),
        ),
    ];

    return CommandPalette(
      groups: [
        (label: l10n.paletteCommands, items: commands),
        (label: l10n.shellSidebarPages, items: pages),
        (label: l10n.paletteRecentFiles, items: recent),
        (label: l10n.settingsTitle, items: settings),
      ],
      onQueryChanged: (query) => setState(() => _query = query),
      onSelected: _run,
      onSearch: document == null ? null : _searchDocument,
      onClose: _close,
      placeholder: l10n.palettePlaceholder,
      emptyText: _query.trim().isEmpty
          ? null
          : document == null
          ? l10n.paletteEmptyNoDocument(_query)
          : l10n.paletteEmpty(_query),
      semanticLabel: l10n.commandPalette,
      escapeKeys: const ['Esc'],
      footerHints: [
        (keys: const ['↑', '↓'], label: l10n.paletteMove),
        (keys: const ['↵'], label: l10n.paletteRun),
        (keys: const ['Esc'], label: l10n.windowClose),
      ],
    );
  }

  /// A row for [command], with its mode as the hint when it works in one.
  static CommandItem _commandItem(
    CommandItem Function(
      String id,
      String label,
      VoidCallback? action, {
      IconName icon,
      String? hint,
      List<String>? shortcut,
      String? disabledReason,
    })
    item,
    ShellCommand command,
    VoidCallback? run,
    AppLocalizations l10n,
    RegionFormat format,
    ShortcutBindings keys, {
    String? disabledReason,
  }) {
    final modes = command.modes;
    final mode = modes != null && modes.length == 1 ? modes.first : null;
    return item(
      command.name,
      l10n.commandLabel(command, format),
      run,
      icon: mode?.icon ?? IconName.command,
      hint: mode == null ? null : l10n.modeLabel(mode),
      shortcut: keys.caps(command),
      disabledReason: disabledReason,
    );
  }

  /// The folder of [path], as the board's hint shows it.
  static String _folderOf(String path) {
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    return slash <= 0 ? path : path.substring(0, slash);
  }
}
