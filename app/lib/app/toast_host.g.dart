// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toast_host.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The toasts that belong to no other state, in the order they came.

@ProviderFor(ToastNotices)
final toastNoticesProvider = ToastNoticesProvider._();

/// The toasts that belong to no other state, in the order they came.
final class ToastNoticesProvider
    extends $NotifierProvider<ToastNotices, List<ToastNotice>> {
  /// The toasts that belong to no other state, in the order they came.
  ToastNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toastNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toastNoticesHash();

  @$internal
  @override
  ToastNotices create() => ToastNotices();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ToastNotice> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ToastNotice>>(value),
    );
  }
}

String _$toastNoticesHash() => r'bfbc533a64044de90bcd4a9aa94fe10c288d8f43';

/// The toasts that belong to no other state, in the order they came.

abstract class _$ToastNotices extends $Notifier<List<ToastNotice>> {
  List<ToastNotice> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<ToastNotice>, List<ToastNotice>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ToastNotice>, List<ToastNotice>>,
              List<ToastNotice>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The height of the task drawer while it is open, 0 while it is closed:
/// toasts stack above it, so they never overlap (decision 31, G49).

@ProviderFor(TaskDrawerHeight)
final taskDrawerHeightProvider = TaskDrawerHeightProvider._();

/// The height of the task drawer while it is open, 0 while it is closed:
/// toasts stack above it, so they never overlap (decision 31, G49).
final class TaskDrawerHeightProvider
    extends $NotifierProvider<TaskDrawerHeight, double> {
  /// The height of the task drawer while it is open, 0 while it is closed:
  /// toasts stack above it, so they never overlap (decision 31, G49).
  TaskDrawerHeightProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskDrawerHeightProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskDrawerHeightHash();

  @$internal
  @override
  TaskDrawerHeight create() => TaskDrawerHeight();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$taskDrawerHeightHash() => r'8d9238c42ab49aaa712c9450f46c172a3213c633';

/// The height of the task drawer while it is open, 0 while it is closed:
/// toasts stack above it, so they never overlap (decision 31, G49).

abstract class _$TaskDrawerHeight extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
