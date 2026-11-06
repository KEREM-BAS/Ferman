import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'background_jobs.g.dart';

/// What a job does, which names its row.
enum BackgroundJobKind {
  /// A copy of a document: the first job, until Compress and Split land.
  copyDocument,
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
    };
  }

  /// The row's second line: where it is, the file it wrote or what went
  /// wrong.
  String? detail(AppLocalizations l10n, RegionFormat format) {
    if (error case final error?) {
      return switch (error.kind) {
        EngineErrorKind.diskFull => l10n.jobFailedDiskFull,
        EngineErrorKind.permissionDenied => l10n.errorFilePermissionDenied,
        _ => engineMessage(l10n, error, bidiIsolate(name)),
      };
    }
    if (state == TaskState.done) {
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
  Completer<bool>? _quit;

  /// Completes when no row works any more, while a quit waits.
  Completer<void>? _ended;

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

  void _start(
    BackgroundJobKind kind,
    String name,
    String? staging,
    Stream<JobUpdate> updates,
  ) {
    final id = _next++;
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
    cancelling: state.cancelling?.id == row.id ? row : state.cancelling,
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
    await _end(id, output?.staged == null ? staging : null, output: output);
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
    if (staging != null) {
      await ref.read(fileAccessProvider).discardStaging(staging);
    }
    final row = _row(id);
    if (row == null) return;
    if (cancelled) {
      _remove(id);
    } else {
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

  /// Whether a quit may go on: with jobs running it asks (decision 30), and
  /// with a yes cancels them and waits for them, so they leave nothing.
  Future<bool> confirmQuit() async {
    final running = state.running;
    if (running.isEmpty) return true;
    final answer = _quit = Completer<bool>();
    state = state.copyWith(quitting: running);
    final yes = await answer.future;
    state = state.copyWith(quitting: const []);
    if (!yes) return false;
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
    return true;
  }

  /// The quit question's answer.
  void answerQuit({required bool quit}) {
    final answer = _quit;
    _quit = null;
    answer?.complete(quit);
  }
}
