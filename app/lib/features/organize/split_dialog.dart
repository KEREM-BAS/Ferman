import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a6-2: the four ways to split the active document, with every file Ferman
/// will write, its pages and size, before anything happens (G142, G143). The
/// split runs as a job with a row in the task drawer (G45).
class SplitDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({super.key});

  /// The modes' column (`grid-template-columns: 260px …`).
  static const double modesWidth = 260;

  /// The height of the list of files at most.
  static const double listHeight = 400;

  /// The template a6-2 starts with.
  static const String template = '{document} — {bookmark}';

  /// The most bytes in a megabyte, as `RegionFormat.fileSize` counts.
  static const int megabyte = 1000000;

  @override
  ConsumerState<SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends ConsumerState<SplitDialog> {
  static const int _typingMs = 250;
  static const Duration _typing = Duration(milliseconds: _typingMs);

  late final ShellDocument _tab = ref.read(shellDocumentsProvider).active!;
  late final int _document = _tab.document!.id;
  final TextEditingController _template = TextEditingController(
    text: SplitDialog.template,
  );

  SplitKind _kind = SplitKind.topBookmarks;
  int _pagesPerFile = 10;
  int _megabytes = 10;

  /// The folder chosen; null is the original's.
  String? _folder;

  /// Whether a bookmark goes to a page, once known.
  bool? _hasBookmarks;
  SplitPreview? _preview;
  EngineException? _error;
  int _generation = 0;
  Timer? _typed;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _typed?.cancel();
    _template.dispose();
    super.dispose();
  }

  String get _targetFolder => _folder ?? folderOf(_tab.path!);

  Future<SplitPreview> _plan(String folder) => ref
      .read(engineServiceProvider)
      .splitPreview(
        _document,
        kind: _kind,
        template: _template.text,
        amount: switch (_kind) {
          SplitKind.everyPages => _pagesPerFile,
          SplitKind.size => _megabytes * SplitDialog.megabyte,
          _ => 0,
        },
        folder: folder,
      );

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _preview = null;
      _error = null;
    });
    try {
      final preview = await _plan(_targetFolder);
      if (!mounted || generation != _generation) return;
      final hasBookmarks = _hasBookmarks ??= preview.bookmarks > 0;
      if (_kind == SplitKind.topBookmarks && !hasBookmarks) {
        // The board's default needs bookmarks to split at.
        _kind = SplitKind.everyPages;
        unawaited(_refresh());
        return;
      }
      setState(() => _preview = preview);
    } on EngineException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    }
  }

  void _select(SplitKind? kind) {
    if (kind == null || kind == _kind) return;
    _kind = kind;
    unawaited(_refresh());
  }

  Future<void> _saveTo(bool choose) async {
    if (!choose) {
      _folder = null;
      unawaited(_refresh());
      return;
    }
    final folder = await ref
        .read(filePickerServiceProvider)
        .chooseFolder(initial: folderOf(_tab.path!));
    if (folder == null || !mounted) return;
    _folder = folder;
    unawaited(_refresh());
  }

  /// Where to write. Under the macOS sandbox, which grants only the file,
  /// "Same folder" asks for the folder through the panel (G143).
  Future<String?> _writableFolder() async {
    if (_folder case final folder?) return folder;
    final access = ref.read(fileAccessProvider);
    final original = _tab.path!;
    final staging = await access.staging(original);
    if (staging == null) return folderOf(original);
    await access.discardStaging(staging);
    return await ref
        .read(filePickerServiceProvider)
        .chooseFolder(initial: folderOf(original));
  }

  Future<void> _split() async {
    final dialogs = ref.read(organizeDialogProvider.notifier);
    final jobs = ref.read(backgroundJobsProvider.notifier);
    final folder = await _writableFolder();
    if (folder == null || !mounted) return;
    try {
      // Again, for the folder it will really write to: names stay free in it.
      final plan = await _plan(folder);
      jobs.split(_document, _tab.name, plan.files, folder);
      dialogs.close();
    } on EngineException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  String _labels(SplitFile file) {
    final pages = _tab.document!.pages;
    String label(int page) => page < pages.length
        ? pages[page].label ?? '${page + 1}'
        : '${page + 1}';
    return file.first == file.last
        ? label(file.first)
        : '${label(file.first)}–${label(file.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final region = ref.watch(regionProvider).region;
    final format = RegionFormat.forRegion(region);
    final dialogs = ref.read(organizeDialogProvider.notifier);
    final preview = _preview;
    final files = preview?.files ?? const <SplitFile>[];
    final blankNone = _kind == SplitKind.blankPages && preview?.blankPages == 0;
    final canSplit = files.isNotEmpty && !blankNone;
    final notes = [
      if (blankNone) l10n.splitNoBlankPages,
      if (preview?.encrypted ?? false) l10n.splitNotProtected,
      if (preview?.signed ?? false) l10n.splitNotSigned,
      if (_error case final error?)
        engineMessage(l10n, error, bidiIsolate(_tab.name)),
    ];
    return Dialog(
      size: DialogSize.lg,
      title: l10n.splitTitle(bidiIsolate(_tab.name)),
      onClose: dialogs.close,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        onPressed: dialogs.close,
        child: Text(l10n.findCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          disabled: !canSplit,
          onPressed: canSplit ? () => unawaited(_split()) : null,
          child: Text(
            l10n.splitAction(files.length, format.integer(files.length)),
          ),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.space5,
        children: [
          SizedBox(
            width: SplitDialog.modesWidth,
            child: Semantics(
              container: true,
              label: l10n.splitBy,
              child: RadioGroup<SplitKind>(
                groupValue: _kind,
                onChanged: _select,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.space.space3,
                  children: [
                    Radio<SplitKind>(
                      value: SplitKind.everyPages,
                      label: l10n.splitEvery,
                      description: l10n.splitEveryBody,
                    ),
                    if (_kind == SplitKind.everyPages)
                      NumberStepper(
                        label: l10n.splitPagesPerFile,
                        value: _pagesPerFile.toDouble(),
                        region: region,
                        min: 1,
                        onChanged: (value) {
                          _pagesPerFile = value.round();
                          unawaited(_refresh());
                        },
                      ),
                    Radio<SplitKind>(
                      value: SplitKind.topBookmarks,
                      label: l10n.splitBookmarks,
                      disabled: _hasBookmarks == false,
                      description: _hasBookmarks == false
                          ? l10n.splitNoBookmarks
                          : l10n.splitBookmarksBody(
                              preview?.bookmarks ?? 0,
                              format.integer(preview?.bookmarks ?? 0),
                            ),
                    ),
                    Radio<SplitKind>(
                      value: SplitKind.size,
                      label: l10n.splitSize,
                      description: l10n.splitSizeBody,
                    ),
                    if (_kind == SplitKind.size)
                      NumberStepper(
                        label: l10n.splitLargest,
                        value: _megabytes.toDouble(),
                        region: region,
                        min: 1,
                        unit: 'MB',
                        onChanged: (value) {
                          _megabytes = value.round();
                          unawaited(_refresh());
                        },
                      ),
                    Radio<SplitKind>(
                      value: SplitKind.blankPages,
                      label: l10n.splitBlank,
                      description: l10n.splitBlankBody,
                    ),
                    TextField(
                      size: FieldSize.sm,
                      label: l10n.splitFileNames,
                      controller: _template,
                      onChanged: (_) {
                        _typed?.cancel();
                        _typed = Timer(_typing, () => unawaited(_refresh()));
                      },
                    ),
                    Select<bool>(
                      size: FieldSize.sm,
                      label: l10n.splitSaveTo,
                      icon: IconName.folder,
                      value: _folder != null,
                      options: [
                        SelectOption(value: false, label: l10n.splitSameFolder),
                        SelectOption(
                          value: true,
                          label: switch (_folder) {
                            final folder? => fileName(folder),
                            null => l10n.splitChooseFolder,
                          },
                        ),
                      ],
                      onChanged: (choose) => unawaited(_saveTo(choose)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.space2,
              children: [
                Text(
                  l10n.organizeFileCount(
                    files.length,
                    format.integer(files.length),
                  ),
                  style: theme.typography.label.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
                if (preview == null && _error == null)
                  const Center(child: Spinner())
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: SplitDialog.listHeight,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.fromBorderSide(
                          BorderSide(color: theme.colors.borderSubtle),
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(theme.radius.radiusMd),
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: files.length,
                        itemBuilder: (context, index) => _FileRow(
                          file: files[index],
                          labels: _labels(files[index]),
                        ),
                      ),
                    ),
                  ),
                for (final note in notes)
                  Text(
                    note,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A file of the list: its icon, name and "i–ix · 9 pages · 0,4 MB".
class _FileRow extends ConsumerWidget {
  const new({required this.file, required this.labels});

  final SplitFile file;
  final String labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final pages = file.last - file.first + 1;
    final meta = [
      labels,
      l10n.organizePageCount(pages, format.integer(pages)),
      format.fileSize(file.bytes),
    ].join(' · ');
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space3,
        vertical: theme.space.space2,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colors.borderSubtle)),
      ),
      child: Row(
        spacing: theme.space.space2_5,
        children: [
          Icon(
            file.overLimit ? IconName.triangleAlert : IconName.fileText,
            color: theme.colors.iconSecondary,
            semanticLabel: file.overLimit ? l10n.splitOverLimit : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
