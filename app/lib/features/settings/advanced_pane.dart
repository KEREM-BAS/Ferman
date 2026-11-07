import 'dart:async';
import 'dart:convert';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the Advanced pane asks before it acts (G50).
sealed class _Ask {
  const new();
}

final class _Reset extends _Ask {
  const new();
}

final class _Import extends _Ask {
  const new(this.json);

  /// The settings file, already checked by [AppSettings.imported].
  final Object? json;
}

/// The Advanced pane of Settings, board a11-1k.
///
/// - The GPU switch (B178), the object inspector (B179) and Show log files
///   (B180) are drawn and disabled.
/// - Page cache and Thumbnails show what the engine does: ferman-render's
///   256 MB tile cache (MiB, as the board counts) and thumbnails made as
///   the Pages tab needs them. The board's other choices are listed and
///   disabled (B212, B213).
/// - Export settings… writes the settings as JSON through the system save
///   panel, without the paths of the documents open last (decision 34).
/// - Import settings… reads such a file through the open panel at a trust
///   boundary ([AppSettings.imported]), says plainly when it is not one,
///   and asks before it replaces the settings (G50).
/// - Reset settings… asks, then sets every setting back to its default.
///   First run stays done, and the open documents and the stamps stay;
///   saved signatures are files of their own and are never touched.
class AdvancedPane extends ConsumerStatefulWidget {
  /// The pane.
  const new({super.key});

  /// The danger box's padding (`padding: 12px 14px`): horizontal …
  static const double resetPaddingX = 14;

  /// … and vertical, which is also its gap.
  static const double resetPaddingY = 12;

  /// The engine's tile cache in decimal megabytes, as the board writes
  /// sizes (ferman-render's `tile_cache_bytes`, 256 MiB).
  static const int engineCacheMegabytes = 256;

  @override
  ConsumerState<AdvancedPane> createState() => _AdvancedPaneState();
}

class _AdvancedPaneState extends ConsumerState<AdvancedPane> {
  _Ask? _ask;

  ToastNotices get _toasts => ref.read(toastNoticesProvider.notifier);

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final picker = ref.read(filePickerServiceProvider);
    final settings = ref.read(settingsProvider);
    final path = await picker.saveFile(
      suggestedName: '${l10n.settingsExportName}.json',
    );
    if (path == null) return;
    final text =
        '${const JsonEncoder.withIndent('  ').convert(settings.toExport())}\n';
    try {
      await picker.writeFile(path, utf8.encode(text));
    } on Object {
      _toasts.show(
        tone: ToastTone.danger,
        title: (l10n) => l10n.settingsExportFailed,
      );
      return;
    }
    _toasts.show(
      tone: ToastTone.success,
      title: (l10n) => l10n.settingsExported,
    );
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final bytes = await ref
        .read(filePickerServiceProvider)
        .openStamp(
          filterLabel: l10n.settingsSettingsFile,
          extension: 'json',
          largest: AppSettings.largestImport,
        );
    if (bytes == null || !mounted) return;
    Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      json = null;
    }
    if (AppSettings.imported(json, ref.read(settingsProvider)) == null) {
      _toasts.show(
        tone: ToastTone.danger,
        title: (l10n) => l10n.settingsImportFailed,
        message: (l10n) => l10n.settingsImportFailedBody,
      );
      return;
    }
    setState(() => _ask = _Import(json));
  }

  void _answer({required bool confirmed}) {
    final ask = _ask;
    setState(() => _ask = null);
    if (!confirmed || ask == null) return;
    unawaited(
      changeSetting(
        ref,
        (current) => switch (ask) {
          _Import(:final json) =>
            AppSettings.imported(json, current) ?? current,
          _Reset() => AppSettings(
            onboardingCompleted: current.onboardingCompleted,
            lastDocuments: current.lastDocuments,
            myStamps: current.myStamps,
          ),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    String megabytes(int value) => format.fileSize(value * 1000 * 1000);
    final ask = _ask;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space4,
      children: [
        Switch(
          value: false,
          label: l10n.settingsGpu,
          disabled: true,
          disabledReason: Feature.gpuRendering.disabledReason(context),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space3,
          children: [
            Expanded(
              child: Select<int>(
                label: l10n.settingsPageCache,
                size: FieldSize.sm,
                value: AdvancedPane.engineCacheMegabytes,
                options: [
                  for (final size in [
                    AdvancedPane.engineCacheMegabytes,
                    1000,
                    2000,
                    512,
                  ])
                    SelectOption(
                      value: size,
                      label: megabytes(size),
                      disabled: size != AdvancedPane.engineCacheMegabytes,
                      disabledReason: size == AdvancedPane.engineCacheMegabytes
                          ? null
                          : Feature.pageCacheSize.disabledReason(context),
                    ),
                ],
                onChanged: (_) {},
              ),
            ),
            Expanded(
              child: Select<bool>(
                label: l10n.settingsThumbnails,
                size: FieldSize.sm,
                value: false,
                options: [
                  SelectOption(
                    value: false,
                    label: l10n.settingsThumbnailsAuto,
                  ),
                  SelectOption(
                    value: true,
                    label: l10n.settingsThumbnailsAll,
                    disabled: true,
                    disabledReason: Feature.thumbnailsUpfront.disabledReason(
                      context,
                    ),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        Switch(
          value: false,
          label: l10n.settingsObjectInspector,
          disabled: true,
          disabledReason: Feature.objectInspector.disabledReason(context),
        ),
        Wrap(
          spacing: theme.space.space2,
          runSpacing: theme.space.space2,
          children: [
            Button(
              size: ButtonSize.sm,
              icon: IconName.fileOutput,
              onPressed: () => unawaited(_export()),
              child: Text(l10n.settingsExport),
            ),
            Button(
              size: ButtonSize.sm,
              icon: IconName.folderOpen,
              onPressed: () => unawaited(_import()),
              child: Text(l10n.settingsImport),
            ),
            Button(
              size: ButtonSize.sm,
              icon: IconName.folder,
              disabledReason: Feature.logFiles.disabledReason(context),
              child: Text(l10n.settingsShowLogs),
            ),
          ],
        ),
        // The dialog sits with the reset box, so the column's gap stays.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AdvancedPane.resetPaddingX,
                vertical: AdvancedPane.resetPaddingY,
              ),
              decoration: BoxDecoration(
                color: colors.dangerBg,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
                border: Border.all(
                  color: colors.dangerBorder,
                  width: theme.border.borderWidth,
                ),
              ),
              child: Row(
                spacing: AdvancedPane.resetPaddingY,
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsReset,
                      style: theme.typography.body,
                    ),
                  ),
                  Button(
                    size: ButtonSize.sm,
                    variant: ButtonVariant.danger,
                    onPressed: () => setState(() => _ask = const _Reset()),
                    child: Text(l10n.settingsResetButton),
                  ),
                ],
              ),
            ),
            if (ask != null)
              Dialog(
                title: switch (ask) {
                  _Reset() => l10n.settingsResetTitle,
                  _Import() => l10n.settingsImportTitle,
                },
                description: switch (ask) {
                  _Reset() => l10n.settingsResetBody,
                  _Import() => l10n.settingsImportBody,
                },
                tone: switch (ask) {
                  _Reset() => DialogTone.danger,
                  _Import() => DialogTone.warning,
                },
                onClose: () => _answer(confirmed: false),
                closeLabel: l10n.organizeCancel,
                cancelAction: Button(
                  onPressed: () => _answer(confirmed: false),
                  child: Text(l10n.organizeCancel),
                ),
                actions: [
                  Button(
                    variant: switch (ask) {
                      _Reset() => ButtonVariant.danger,
                      _Import() => ButtonVariant.primary,
                    },
                    autofocus: true,
                    onPressed: () => _answer(confirmed: true),
                    child: Text(switch (ask) {
                      _Reset() => l10n.settingsResetConfirm,
                      _Import() => l10n.settingsImportConfirm,
                    }),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
