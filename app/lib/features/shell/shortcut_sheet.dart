import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The keyboard cheat sheet (a11-3, B076): ⌘/ or Ctrl+/, and the palette's
/// Show keyboard shortcuts, shown through `organizeDialogProvider`.
///
/// Every command with keys on this system (`shortcutBindingsProvider`, the
/// user's changes included) under its group, GENERAL to WINDOW, in four
/// columns; fewer below a 1100 px window (M4 decision 32). A command whose
/// keys the user changed carries the Changed mark, and one left with no key
/// says so. The search field filters by name or by caps ("⌘K"), folding
/// case with the UI language's rules. For screen readers each row is one
/// command–key pair.
class ShortcutSheet extends ConsumerStatefulWidget {
  /// The sheet.
  const new({super.key});

  /// a11-3's dialog width.
  static const double boardWidth = 1100;

  /// a11-3's search field width.
  static const double searchWidth = 260;

  /// The window widths below which the sheet has three, then two, columns.
  static const double threeColumnsBelow = 1100;

  /// See [threeColumnsBelow].
  static const double twoColumnsBelow = 800;

  @override
  ConsumerState<ShortcutSheet> createState() => _ShortcutSheetState();
}

class _ShortcutSheetState extends ConsumerState<ShortcutSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final keys = ref.watch(shortcutBindingsProvider);
    final query = casing.lower(_query.trim()).replaceAll(' ', '');
    bool matches(String label, List<String>? caps) =>
        query.isEmpty ||
        casing.lower(label).contains(query) ||
        casing.lower((caps ?? const []).join()).contains(query);

    final groups = [
      for (final group in ShortcutGroup.values)
        (
          group: group,
          rows: [
            for (final command in ShellCommand.values)
              if (command.group == group &&
                  (keys.of(command).isNotEmpty || keys.changed(command)) &&
                  matches(
                    l10n.commandLabel(command, format),
                    keys.caps(command),
                  ))
                command,
          ],
        ),
    ].where((group) => group.rows.isNotEmpty).toList();

    final width = MediaQuery.sizeOf(context).width;
    final columns = width < ShortcutSheet.twoColumnsBelow
        ? 2
        : width < ShortcutSheet.threeColumnsBelow
        ? 3
        : 4;
    final labelStyle = theme.typography.label;

    Widget row(ShellCommand command) {
      final caps = keys.caps(command);
      final label = l10n.commandLabel(command, format);
      return MergeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.space.space6),
          child: Row(
            spacing: theme.space.space2,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.typography.body.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (keys.changed(command))
                Text(
                  l10n.shortcutsChanged,
                  style: theme.typography.caption.copyWith(
                    color: colors.textAccent,
                  ),
                ),
              if (caps == null)
                Text(
                  l10n.shortcutsNone,
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                )
              else
                Kbd(caps),
            ],
          ),
        ),
      );
    }

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final gap = theme.space.space6;
        final columnWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space4,
          children: [
            if (groups.isEmpty)
              Text(
                l10n.shortcutsNoMatch(_query.trim()),
                style: theme.typography.body.copyWith(
                  color: colors.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: gap,
                runSpacing: theme.space.space4 + theme.space.space0_5,
                children: [
                  for (final group in groups)
                    SizedBox(
                      width: columnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space1_5,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              casing.upper(
                                l10n.shortcutGroupLabel(group.group),
                              ),
                              style: labelStyle.copyWith(
                                color: colors.textTertiary,
                                letterSpacing:
                                    theme.typeScale.trackingLabel *
                                    labelStyle.fontSize!,
                              ),
                            ),
                          ),
                          for (final command in group.rows) row(command),
                        ],
                      ),
                    ),
                ],
              ),
            Text(
              l10n.shortcutsSheetNote,
              style: theme.typography.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        );
      },
    );

    return Dialog(
      title: l10n.settingsPaneShortcuts,
      width: ShortcutSheet.boardWidth,
      onClose: ref.read(organizeDialogProvider.notifier).close,
      closeLabel: l10n.windowClose,
      headTrailing: SizedBox(
        width: ShortcutSheet.searchWidth,
        child: TextField(
          size: FieldSize.sm,
          icon: IconName.search,
          placeholder: l10n.shortcutsSheetSearch,
          semanticLabel: l10n.shortcutsSheetSearch,
          autofocus: true,
          onChanged: (text) => setState(() => _query = text),
        ),
      ),
      child: body,
    );
  }
}
