import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/file_exists.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'background_jobs.g.dart';

/// What a job does, which names its row.
enum BackgroundJobKind {
  /// A copy of a document: the first job, until Compress lands.
  copyDocument,

  /// Pages of a document written as new files (G45).
  extractPages,

  /// Pages of a file read for an insert (G45).
  insertPages,

  /// Pages of a file read for a replace (G45).
  replacePages,

  /// A split of a document into new files (a6-2, G45).
  split,

  /// Files combined into a new file (a6-3, G45).
  combine,

  /// Create PDF (B019): a new file that opens once written.
  create,

  /// A comment summary written as a new file (a4-4).
  commentSummary,

  /// Comments drawn into the pages, after an optional copy (a4-5b).
  flattenComments,

  /// A compressed copy written as a new file (a9-1).
  compress,
}

/// A row of the task drawer (a11-6b).
@immutable
final class BackgroundJob {
  /// A row.
  const new({
    required this.id,
    required this.kind,
    required this.name,
    this.job,
    this.state = TaskState.running,
    this.value,
    this.messageKey,
    this.params = const {},
    this.output,
    this.error,
  });

  /// The row's own number: the engine's handle comes with its first event.
  final int id;

  /// What it does.
  final BackgroundJobKind kind;

  /// The document's or file's name, untrusted text from the outside.
  final String name;

  /// The engine's handle, once known.
  final int? job;

  /// Running, paused, done or failed.
  final TaskState state;

  /// How far it is, 0 to 1; null when unknown.
  final double? value;

  /// The ARB key of where it is, and its parameters.
  final String? messageKey;

  /// The parameters of [messageKey].
  final Map<String, String> params;

  /// The file it wrote, which Show shows.
  final String? output;

  /// Why it failed.
  final EngineException? error;

  /// Whether it still works.
  bool get active => state == TaskState.running || state == TaskState.paused;

  /// The row's icon while it works (FmWindow's task).
  IconName get icon => switch (kind) {
    BackgroundJobKind.copyDocument => IconName.copy,
    BackgroundJobKind.extractPages => IconName.fileOutput,
    BackgroundJobKind.insertPages => IconName.filePlus2,
    BackgroundJobKind.replacePages => IconName.replace,
    BackgroundJobKind.split => IconName.split,
    BackgroundJobKind.combine => IconName.merge,
    BackgroundJobKind.create => IconName.filePlus2,
    BackgroundJobKind.commentSummary => IconName.messageSquare,
    BackgroundJobKind.flattenComments => IconName.layers,
    BackgroundJobKind.compress => IconName.minimize2,
  };

  /// The row's title in [state].
  String title(AppLocalizations l10n) {
    final name = bidiIsolate(this.name);
    return switch ((kind, state)) {
      (BackgroundJobKind.copyDocument, TaskState.running || TaskState.paused) =>
        l10n.jobCopyingTitle(name),
      (BackgroundJobKind.copyDocument, TaskState.done) => l10n.jobCopiedTitle(
        name,
      ),
      (BackgroundJobKind.copyDocument, TaskState.error) =>
        l10n.jobCopyFailedTitle(name),
      (BackgroundJobKind.extractPages, TaskState.running || TaskState.paused) =>
        l10n.jobExtractingTitle(name),
      (BackgroundJobKind.extractPages, TaskState.done) =>
        l10n.jobExtractedTitle(name),
      (BackgroundJobKind.extractPages, TaskState.error) =>
        l10n.jobExtractFailedTitle(name),
      (BackgroundJobKind.insertPages, TaskState.running || TaskState.paused) =>
        l10n.jobInsertingTitle(name),
      (BackgroundJobKind.insertPages, TaskState.done) => l10n.jobInsertedTitle(
        name,
      ),
      (BackgroundJobKind.insertPages, TaskState.error) =>
        l10n.jobInsertFailedTitle(name),
      (BackgroundJobKind.replacePages, TaskState.running || TaskState.paused) =>
        l10n.jobReplacingTitle(name),
      (BackgroundJobKind.replacePages, TaskState.done) => l10n.jobReplacedTitle(
        name,
      ),
      (BackgroundJobKind.replacePages, TaskState.error) =>
        l10n.jobReplaceFailedTitle(name),
      (BackgroundJobKind.split, TaskState.running || TaskState.paused) =>
        l10n.jobSplittingTitle(name),
      (BackgroundJobKind.split, TaskState.done) => l10n.jobSplitTitle(name),
      (BackgroundJobKind.split, TaskState.error) => l10n.jobSplitFailedTitle(
        name,
      ),
      (BackgroundJobKind.combine, TaskState.running || TaskState.paused) =>
        l10n.jobCombiningTitle(name),
      (BackgroundJobKind.combine, TaskState.done) => l10n.jobCombinedTitle(
        name,
      ),
      (BackgroundJobKind.combine, TaskState.error) =>
        l10n.jobCombineFailedTitle(name),
      (BackgroundJobKind.create, TaskState.running || TaskState.paused) =>
        l10n.jobCreatingTitle(name),
      (BackgroundJobKind.create, TaskState.done) => l10n.jobCreatedTitle(name),
      (BackgroundJobKind.create, TaskState.error) => l10n.jobCreateFailedTitle(
        name,
      ),
      (
        BackgroundJobKind.commentSummary,
        TaskState.running || TaskState.paused,
      ) =>
        l10n.jobSummaryRunningTitle(name),
      (BackgroundJobKind.commentSummary, TaskState.done) =>
        l10n.jobSummaryDoneTitle(name),
      (BackgroundJobKind.commentSummary, TaskState.error) =>
        l10n.jobSummaryFailedTitle(name),
      (
        BackgroundJobKind.flattenComments,
        TaskState.running || TaskState.paused,
      ) =>
        l10n.jobFlatteningTitle(name),
      (BackgroundJobKind.flattenComments, TaskState.done) =>
        l10n.jobFlattenedTitle(name),
      (BackgroundJobKind.flattenComments, TaskState.error) =>
        l10n.jobFlattenFailedTitle(name),
      (BackgroundJobKind.compress, TaskState.running || TaskState.paused) =>
        l10n.jobCompressingTitle(name),
      (BackgroundJobKind.compress, TaskState.done) => l10n.jobCompressedTitle(
        name,
      ),
      (BackgroundJobKind.compress, TaskState.error) =>
        l10n.jobCompressFailedTitle(name),
    };
  }

  /// The row's second line: where it is, the file it wrote or what went
  /// wrong.
  String? detail(AppLocalizations l10n, RegionFormat format) {
    if (error case final error?) {
      return switch (error.kind) {
        EngineErrorKind.diskFull => l10n.jobFailedDiskFull,
        EngineErrorKind.permissionDenied => l10n.errorFilePermissionDenied,
        // B202: a page whose content leaks a state past a `Q` too many.
        EngineErrorKind.unsupported
            when kind == BackgroundJobKind.commentSummary =>
          l10n.jobSummaryPageUnsupported,
        EngineErrorKind.unsupported
            when kind == BackgroundJobKind.flattenComments =>
          l10n.jobFlattenPageUnsupported,
        _ => engineMessage(l10n, error, bidiIsolate(name)),
      };
    }
    if (state == TaskState.done && kind == BackgroundJobKind.compress) {
      // The engine's facts: a result no smaller writes nothing (decision 25).
      final before = int.tryParse(params['before'] ?? '');
      final after = int.tryParse(params['after'] ?? '');
      if (params['written'] == 'false') return l10n.jobCompressNotSmaller;
      if (before != null && after != null) {
        return l10n.jobCompressedSizes(
          format.fileSize(before),
          format.fileSize(after),
        );
      }
    }
    if (state == TaskState.done) {
      if (int.tryParse(params['files'] ?? '') case final files?
          when kind == BackgroundJobKind.split || files > 1) {
        return l10n.organizeFileCount(files, format.integer(files));
      }
      final file = output?.split(RegExp(r'[/\\]')).last;
      return file == null ? null : bidiIsolate(file);
    }
    final page = int.tryParse(params['page'] ?? '');
    final pages = int.tryParse(params['pages'] ?? '');
    if (messageKey != 'jobPageOf' || page == null || pages == null) return null;
    return state == TaskState.paused
        ? l10n.jobPausedAtPage(format.integer(page))
        : l10n.jobPageOf(format.integer(page), format.integer(pages));
  }

  /// This row with the fields given.
  BackgroundJob copyWith({
    int? job,
    TaskState? state,
    double? value,
    String? messageKey,
    Map<String, String>? params,
    String? output,
    EngineException? error,
  }) => BackgroundJob(
    id: id,
    kind: kind,
    name: name,
    job: job ?? this.job,
    state: state ?? this.state,
    value: value ?? this.value,
    messageKey: messageKey ?? this.messageKey,
    params: params ?? this.params,
    output: output ?? this.output,
    error: error ?? this.error,
  );
}

/// What `backgroundJobsProvider` holds.
@immutable
final class BackgroundJobs {
  /// The state.
  const new({
    this.rows = const [],
    this.open = false,
    this.cancelling,
    this.quitting = const [],
  });

  /// The rows, oldest first.
  final List<BackgroundJob> rows;

  /// Whether the drawer shows.
  final bool open;

  /// The row whose cancel waits for its confirmation (G49).
  final BackgroundJob? cancelling;

  /// The rows a quit asks about (decision 30); empty when it does not ask.
  final List<BackgroundJob> quitting;

  /// The rows still working.
  List<BackgroundJob> get running => [
    for (final row in rows)
      if (row.active) row,
  ];

  /// This state with the fields given; [cancelling] goes unless given.
  BackgroundJobs copyWith({
    List<BackgroundJob>? rows,
    bool? open,
    BackgroundJob? cancelling,
    List<BackgroundJob>? quitting,
  }) => BackgroundJobs(
    rows: rows ?? this.rows,
    open: open ?? this.open,
    cancelling: cancelling,
    quitting: quitting ?? this.quitting,
  );
}

/// The background jobs and the task drawer, as `backgroundJobsProvider`
/// (a11-6b, G49): a row for each job from its start until it is dismissed, an
/// hour after it finished, or as soon as it is cancelled. Jobs outlive their
/// tabs, so nothing here listens to documents.
@Riverpod(keepAlive: true)
class BackgroundJobsNotifier extends _$BackgroundJobsNotifier {
  int _next = 1;
  final Map<int, StreamSubscription<JobUpdate>> _subscriptions = {};
  final Map<int, Timer> _expiries = {};

  /// What waits for a row's end ([insertPages]), by row.
  final Map<int, Completer<int?>> _waiting = {};
  Completer<bool>? _quit;

  /// Completes when no row works any more, while a quit waits.
  Completer<void>? _ended;

  /// What follows each job that finishes, by row: the change it prepared.
  final Map<int, Future<EngineException?> Function(JobUpdate)> _thens = {};

  /// The rows whose file opens once written: Create PDF.
  final Set<int> _opens = {};

  @override
  BackgroundJobs build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions.values) {
        unawaited(subscription.cancel());
      }
      for (final timer in _expiries.values) {
        timer.cancel();
      }
    });
    return const BackgroundJobs();
  }

  /// Shows the drawer: the status bar's task and, from W5, the palette.
  void openDrawer() =>
      state = state.copyWith(open: true, cancelling: state.cancelling);

  /// Hides the drawer; the jobs go on.
  void closeDrawer() {
    state = state.copyWith(open: false, cancelling: state.cancelling);
    ref.read(taskDrawerHeightProvider.notifier).set(0);
  }

  /// The status bar's task.
  void toggleDrawer() => state.open ? closeDrawer() : openDrawer();

  /// Copies [document], named [name], to the new file [output] as a job.
  Future<void> copyDocument(int document, String name, String output) async {
    final access = ref.read(fileAccessProvider);
    final staging = await access.staging(output);
    _start(
      BackgroundJobKind.copyDocument,
      name,
      staging,
      ref
          .read(engineServiceProvider)
          .copyDocumentJob(document, output, staging: staging),
    );
  }

  /// Reads the pages of the file at [path], named [name], to go into [document]
  /// as a job. Its result is the job, whose change `applyJobChange` commits, or
  /// null when it was cancelled; throws its [EngineException].
  Future<int?> insertPages(
    int document,
    String name, {
    required String path,
    required int? after,
    required ImagePaper paper,
    required String stepName,
  }) {
    final done = Completer<int?>();
    _waiting[_next] = done;
    _start(
      BackgroundJobKind.insertPages,
      name,
      null,
      ref
          .read(engineServiceProvider)
          .insertPagesJob(
            document,
            path: path,
            after: after,
            paper: paper,
            name: stepName,
          ),
    );
    return done.future;
  }

  /// Writes [pages] of [document], named [name], as the new file [output] as a
  /// job; with [deleteName], it then deletes them as that step.
  Future<void> extractPages(
    int document,
    String name,
    List<int> pages, {
    required String output,
    String? deleteName,
  }) async {
    final staging = await ref.read(fileAccessProvider).staging(output);
    _start(
      BackgroundJobKind.extractPages,
      name,
      staging,
      ref
          .read(engineServiceProvider)
          .extractPagesJob(document, pages, output: output, staging: staging),
      then: _deleting(document, pages, deleteName),
    );
  }

  /// Writes each of [files] of [document], named [name], into [folder] as one
  /// job; with [deleteName], it then deletes [pages], by handle, as that step.
  /// The folder panel's grant covers the new files, so nothing needs staging.
  void extractEachPage(
    int document,
    String name,
    List<SplitFile> files, {
    required String folder,
    required List<int> pages,
    String? deleteName,
  }) => _start(
    BackgroundJobKind.extractPages,
    name,
    null,
    ref.read(engineServiceProvider).splitJob(document, files, folder: folder),
    then: _deleting(document, pages, deleteName),
  );

  /// The delete after an extract, whose file is written whatever becomes of it:
  /// a refusal says so on its own and leaves the row done.
  Future<EngineException?> Function(JobUpdate)? _deleting(
    int document,
    List<int> pages,
    String? name,
  ) => name == null
      ? null
      : (_) async {
          final failure = await ref
              .read(documentEditorProvider.notifier)
              .pageChange(
                document,
                () => ref
                    .read(engineServiceProvider)
                    .deletePages(document, pages, name),
              );
          if (failure != null) {
            ref
                .read(toastNoticesProvider.notifier)
                .show(
                  tone: ToastTone.danger,
                  title: (l10n) => l10n.organizeFailed,
                  message: (l10n) => engineMessage(l10n, failure, name),
                );
          }
          return null;
        };

  /// Reads the file [name] through [updates] as a job of [kind], then commits
  /// the change it prepared to [document] as one step; [staging] holds a file
  /// the job writes on the way.
  void pagesFromFile(
    BackgroundJobKind kind,
    int document,
    String name,
    Stream<JobUpdate> updates, {
    String? staging,
  }) => _start(
    kind,
    name,
    staging,
    updates,
    then: (done) => ref
        .read(documentEditorProvider.notifier)
        .pageChange(
          document,
          () => ref.read(engineServiceProvider).applyJobChange(done.job),
        ),
  );

  /// Writes [files] to the new file [output] as a job: Combine and, as
  /// [BackgroundJobKind.create], Create PDF, whose file then opens. A name that
  /// is taken says so: a job never overwrites.
  Future<void> combine(
    List<CombineInput> files, {
    required bool keepForms,
    required String output,
    BackgroundJobKind kind = BackgroundJobKind.combine,
  }) async {
    final name = fileName(output);
    if (await fileExists(output)) {
      ref
          .read(toastNoticesProvider.notifier)
          .show(
            tone: ToastTone.danger,
            title: (l10n) => l10n.combineOutputExists(bidiIsolate(name)),
          );
      return;
    }
    final staging = await ref.read(fileAccessProvider).staging(output);
    if (kind == BackgroundJobKind.create) _opens.add(_next);
    _start(
      kind,
      name,
      staging,
      ref
          .read(engineServiceProvider)
          .combineJob(
            files,
            keepForms: keepForms,
            paper: switch (ref.read(regionProvider).paperSize) {
              PaperSize.a4 => ImagePaper.a4,
              PaperSize.letter => ImagePaper.letter,
            },
            output: output,
            staging: staging,
          ),
    );
  }

  /// Writes the comments of [document] to the new file [output] as a job. A
  /// name that is taken says so: a job never overwrites.
  Future<void> commentSummary(
    int document, {
    required String output,
    required SummaryFormat format,
    required SummaryOptions options,
  }) async {
    final name = fileName(output);
    if (await fileExists(output)) {
      ref
          .read(toastNoticesProvider.notifier)
          .show(
            tone: ToastTone.danger,
            title: (l10n) => l10n.combineOutputExists(bidiIsolate(name)),
          );
      return;
    }
    final staging = await ref.read(fileAccessProvider).staging(output);
    _start(
      BackgroundJobKind.commentSummary,
      name,
      staging,
      ref
          .read(engineServiceProvider)
          .commentSummaryJob(
            document,
            format,
            options,
            output: output,
            staging: staging,
          ),
    );
  }

  /// Draws the comments [handles] of [document], named [name], into its pages
  /// as a job (a4-5b), then commits that as the step [step]; with [copy] it
  /// first writes the document as it stands to that new file, and if that
  /// fails nothing changes (G146). Ask for a signed document's confirmation
  /// first (`afterSigned`).
  Future<void> flattenComments(
    int document,
    String name,
    List<int> handles, {
    required String step,
    String? copy,
  }) async {
    final staging = copy == null
        ? null
        : await ref.read(fileAccessProvider).staging(copy);
    pagesFromFile(
      BackgroundJobKind.flattenComments,
      document,
      name,
      ref
          .read(engineServiceProvider)
          .flattenAnnotationsJob(
            document,
            handles,
            name: step,
            copy: copy,
            staging: staging,
          ),
      staging: staging,
    );
  }

  /// Compresses [document], named [name], with [preset] into the new file
  /// [output] as a job (a9-1); a signed document needs [unsign], its warning
  /// accepted (decision 25). A name that is taken says so: a job never
  /// overwrites.
  Future<void> compress(
    int document,
    String name, {
    required CompressPreset preset,
    required String output,
    bool unsign = false,
  }) async {
    if (await fileExists(output)) {
      ref
          .read(toastNoticesProvider.notifier)
          .show(
            tone: ToastTone.danger,
            title: (l10n) =>
                l10n.combineOutputExists(bidiIsolate(fileName(output))),
          );
      return;
    }
    final staging = await ref.read(fileAccessProvider).staging(output);
    _start(
      BackgroundJobKind.compress,
      name,
      staging,
      ref
          .read(engineServiceProvider)
          .compressJob(
            document,
            preset: preset,
            output: output,
            unsign: unsign,
            staging: staging,
          ),
    );
  }

  /// Writes [files] of [document], named [name], into [folder] as a job. There
  /// is no staging: under the macOS sandbox the folder panel granted [folder]
  /// itself (G143), and a shared staging directory goes at the first swap.
  void split(int document, String name, List<SplitFile> files, String folder) =>
      _start(
        BackgroundJobKind.split,
        name,
        null,
        ref
            .read(engineServiceProvider)
            .splitJob(document, files, folder: folder),
      );

  void _start(
    BackgroundJobKind kind,
    String name,
    String? staging,
    Stream<JobUpdate> updates, {
    Future<EngineException?> Function(JobUpdate done)? then,
  }) {
    final id = _next++;
    if (then != null) _thens[id] = then;
    state = state.copyWith(
      rows: [
        ...state.rows,
        BackgroundJob(id: id, kind: kind, name: name),
      ],
      cancelling: state.cancelling,
    );
    _subscriptions[id] = updates.listen(
      (update) => unawaited(_update(id, staging, update)),
      onError: (Object error) => unawaited(
        _end(
          id,
          staging,
          error: error is EngineException
              ? error
              : const EngineException(messageKey: 'errorInternal'),
        ),
      ),
    );
  }

  BackgroundJob? _row(int id) =>
      state.rows.where((row) => row.id == id).firstOrNull;

  void _replace(BackgroundJob row) => state = state.copyWith(
    rows: [
      for (final other in state.rows)
        if (other.id == row.id) row else other,
    ],
    // A job that ended has nothing left to cancel.
    cancelling: state.cancelling?.id == row.id
        ? (row.active ? row : null)
        : state.cancelling,
  );

  Future<void> _update(int id, String? staging, JobUpdate update) async {
    final row = _row(id);
    if (row == null) return;
    switch (update.state) {
      case JobState.running || JobState.paused:
        _replace(
          row.copyWith(
            job: update.job,
            state: update.state == JobState.paused
                ? TaskState.paused
                : TaskState.running,
            value: update.progress,
            messageKey: update.messageKey,
            params: update.params,
          ),
        );
      case JobState.cancelled:
        await _end(id, staging, cancelled: true);
      case JobState.failed:
        await _end(
          id,
          staging,
          error:
              update.error ??
              const EngineException(messageKey: 'errorInternal'),
        );
      case JobState.done:
        _replace(row.copyWith(job: update.job));
        await _finish(id, staging, update);
    }
  }

  /// Puts a staged output in place; the row is done, or failed when the swap
  /// failed, and the file as it was.
  Future<void> _finish(int id, String? staging, JobUpdate update) async {
    final access = ref.read(fileAccessProvider);
    final output = update.outputs.firstOrNull;
    if (output?.staged case final staged?) {
      final failure = await access.swapIn(staged, output!.path);
      if (failure != null) {
        await _end(
          id,
          null,
          error: EngineException(
            kind: switch (failure) {
              SwapFailure.permission => EngineErrorKind.permissionDenied,
              SwapFailure.diskFull => EngineErrorKind.diskFull,
              SwapFailure.locked => EngineErrorKind.fileLocked,
              SwapFailure.volumeGone => EngineErrorKind.volumeGone,
              SwapFailure.other => EngineErrorKind.renameFailed,
            },
            messageKey: 'errorFileWrite',
          ),
        );
        return;
      }
    }
    if (_row(id) case final row?) {
      _replace(
        row.copyWith(
          params: {...update.params, 'files': '${update.outputs.length}'},
        ),
      );
    }
    await _end(
      id,
      output?.staged == null ? staging : null,
      output: output,
      error: await _thens[id]?.call(update),
    );
    if (_opens.remove(id) && output != null) {
      await ref.read(documentOpenerProvider.notifier).open([output.path]);
    }
  }

  /// A row's end: a cancelled one goes, the others stay for an hour.
  Future<void> _end(
    int id,
    String? staging, {
    bool cancelled = false,
    EngineException? error,
    JobOutputFile? output,
  }) async {
    unawaited(_subscriptions.remove(id)?.cancel());
    _thens.remove(id);
    if (staging != null) {
      await ref.read(fileAccessProvider).discardStaging(staging);
    }
    final row = _row(id);
    final waiting = _waiting.remove(id);
    if (error != null) {
      waiting?.completeError(error);
    } else {
      waiting?.complete(cancelled ? null : row?.job);
    }
    if (row == null) return;
    if (cancelled) {
      _opens.remove(id);
      _remove(id);
    } else {
      // The start screen has no status bar to lead to the drawer's row.
      if (error != null && _opens.remove(id)) {
        ref
            .read(toastNoticesProvider.notifier)
            .show(
              tone: ToastTone.danger,
              title: (l10n) => l10n.jobCreateFailedTitle(bidiIsolate(row.name)),
            );
      }
      _replace(
        row.copyWith(
          state: error == null ? TaskState.done : TaskState.error,
          output: output?.path,
          error: error,
        ),
      );
      _expiries[id] = Timer(jobResultKept, () => dismiss(id));
    }
    if (state.running.isEmpty && !(_ended?.isCompleted ?? true)) {
      _ended?.complete();
    }
    if (state.quitting.isNotEmpty) {
      // The quit question lists what still runs, and has nothing to ask once
      // nothing does.
      state = state.copyWith(
        quitting: state.running,
        cancelling: state.cancelling,
      );
      if (state.quitting.isEmpty) answerQuit(quit: true);
    }
  }

  void _remove(int id) {
    _expiries.remove(id)?.cancel();
    state = state.copyWith(
      rows: [
        for (final row in state.rows)
          if (row.id != id) row,
      ],
      cancelling: state.cancelling?.id == id ? null : state.cancelling,
    );
  }

  /// Takes a finished row away.
  void dismiss(int id) => _remove(id);

  /// Shows [row]'s file in the file manager (a11-6b's Show).
  Future<void> show(BackgroundJob row) async {
    if (row.output case final path?) {
      await ref.read(fileAccessProvider).show(path);
    }
  }

  /// Parks [row]'s job at its next step.
  Future<void> pause(BackgroundJob row) async {
    if (row.job case final job?) {
      await ref.read(engineServiceProvider).pauseJob(job);
    }
  }

  /// Lets [row]'s job go on.
  Future<void> resume(BackgroundJob row) async {
    if (row.job case final job?) {
      await ref.read(engineServiceProvider).resumeJob(job);
    }
  }

  /// Asks before cancelling [row] (G49).
  void askCancel(BackgroundJob row) => state = state.copyWith(cancelling: row);

  /// The question's "Keep running".
  void keepRunning() => state = state.copyWith();

  /// The question's "Cancel task": the row goes when the job has stopped.
  Future<void> confirmCancel() async {
    final job = state.cancelling?.job;
    state = state.copyWith();
    if (job != null) await ref.read(engineServiceProvider).cancelJob(job);
  }

  /// Whether a quit may go on: with jobs running it asks (decision 30). The
  /// jobs keep running until [cancelForQuit], since the question about unsaved
  /// documents that comes next can still stop the quit.
  Future<bool> confirmQuit() async {
    final running = state.running;
    if (running.isEmpty) return true;
    final answer = _quit = Completer<bool>();
    state = state.copyWith(quitting: running);
    final yes = await answer.future;
    state = state.copyWith(quitting: const []);
    return yes;
  }

  /// For a quit nothing stops any more: cancels the running jobs and waits for
  /// them, so they leave nothing.
  Future<void> cancelForQuit() async {
    final running = state.running;
    if (running.isEmpty) return;
    final ended = _ended = Completer<void>();
    final engine = ref.read(engineServiceProvider);
    for (final row in running) {
      if (row.job case final job?) await engine.cancelJob(job);
    }
    final patience = Timer(jobQuitWait, () {
      if (!ended.isCompleted) ended.complete();
    });
    await ended.future;
    patience.cancel();
    _ended = null;
  }

  /// The quit question's answer.
  void answerQuit({required bool quit}) {
    final answer = _quit;
    _quit = null;
    answer?.complete(quit);
  }
}
