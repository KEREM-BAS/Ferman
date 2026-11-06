// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_jobs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The background jobs and the task drawer, as `backgroundJobsProvider`
/// (a11-6b, G49): a row for each job from its start until it is dismissed, an
/// hour after it finished, or as soon as it is cancelled. Jobs outlive their
/// tabs, so nothing here listens to documents.

@ProviderFor(BackgroundJobsNotifier)
final backgroundJobsProvider = BackgroundJobsNotifierProvider._();

/// The background jobs and the task drawer, as `backgroundJobsProvider`
/// (a11-6b, G49): a row for each job from its start until it is dismissed, an
/// hour after it finished, or as soon as it is cancelled. Jobs outlive their
/// tabs, so nothing here listens to documents.
final class BackgroundJobsNotifierProvider
    extends $NotifierProvider<BackgroundJobsNotifier, BackgroundJobs> {
  /// The background jobs and the task drawer, as `backgroundJobsProvider`
  /// (a11-6b, G49): a row for each job from its start until it is dismissed, an
  /// hour after it finished, or as soon as it is cancelled. Jobs outlive their
  /// tabs, so nothing here listens to documents.
  BackgroundJobsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundJobsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundJobsNotifierHash();

  @$internal
  @override
  BackgroundJobsNotifier create() => BackgroundJobsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundJobs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundJobs>(value),
    );
  }
}

String _$backgroundJobsNotifierHash() =>
    r'dc94cbe58b37ff37464f3abb39125479733e8040';

/// The background jobs and the task drawer, as `backgroundJobsProvider`
/// (a11-6b, G49): a row for each job from its start until it is dismissed, an
/// hour after it finished, or as soon as it is cancelled. Jobs outlive their
/// tabs, so nothing here listens to documents.

abstract class _$BackgroundJobsNotifier extends $Notifier<BackgroundJobs> {
  BackgroundJobs build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BackgroundJobs, BackgroundJobs>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BackgroundJobs, BackgroundJobs>,
              BackgroundJobs,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
