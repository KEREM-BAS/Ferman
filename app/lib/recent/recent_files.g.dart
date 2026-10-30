// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_files.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's home directory on macOS and Linux, which the recent files
/// show as "~" (a1-4: "~/Belgeler/Ev"); null on Windows and the web.
/// `bootstrap()` overrides it.

@ProviderFor(homeDirectory)
final homeDirectoryProvider = HomeDirectoryProvider._();

/// The user's home directory on macOS and Linux, which the recent files
/// show as "~" (a1-4: "~/Belgeler/Ev"); null on Windows and the web.
/// `bootstrap()` overrides it.

final class HomeDirectoryProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The user's home directory on macOS and Linux, which the recent files
  /// show as "~" (a1-4: "~/Belgeler/Ev"); null on Windows and the web.
  /// `bootstrap()` overrides it.
  HomeDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeDirectoryHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return homeDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$homeDirectoryHash() => r'1f014019a63a0e389c0104ae6d2b9a5fa36bf270';

/// The recent files' sort and view, as `recentLayoutProvider`: kept for the
/// session, so leaving the start screen and coming back keeps them (G118).

@ProviderFor(RecentLayout)
final recentLayoutProvider = RecentLayoutProvider._();

/// The recent files' sort and view, as `recentLayoutProvider`: kept for the
/// session, so leaving the start screen and coming back keeps them (G118).
final class RecentLayoutProvider
    extends $NotifierProvider<RecentLayout, (RecentSort, RecentView)> {
  /// The recent files' sort and view, as `recentLayoutProvider`: kept for the
  /// session, so leaving the start screen and coming back keeps them (G118).
  RecentLayoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentLayoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentLayoutHash();

  @$internal
  @override
  RecentLayout create() => RecentLayout();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue((RecentSort, RecentView) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<(RecentSort, RecentView)>(value),
    );
  }
}

String _$recentLayoutHash() => r'0c7e267197bab539068e3048d3534ff65431b097';

/// The recent files' sort and view, as `recentLayoutProvider`: kept for the
/// session, so leaving the start screen and coming back keeps them (G118).

abstract class _$RecentLayout extends $Notifier<(RecentSort, RecentView)> {
  (RecentSort, RecentView) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<(RecentSort, RecentView), (RecentSort, RecentView)>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<(RecentSort, RecentView), (RecentSort, RecentView)>,
              (RecentSort, RecentView),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Where the recent files are stored. `bootstrap()` overrides it with the
/// platform's store.

@ProviderFor(recentFilesStore)
final recentFilesStoreProvider = RecentFilesStoreProvider._();

/// Where the recent files are stored. `bootstrap()` overrides it with the
/// platform's store.

final class RecentFilesStoreProvider
    extends
        $FunctionalProvider<
          RecentFilesStore,
          RecentFilesStore,
          RecentFilesStore
        >
    with $Provider<RecentFilesStore> {
  /// Where the recent files are stored. `bootstrap()` overrides it with the
  /// platform's store.
  RecentFilesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentFilesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentFilesStoreHash();

  @$internal
  @override
  $ProviderElement<RecentFilesStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecentFilesStore create(Ref ref) {
    return recentFilesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecentFilesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecentFilesStore>(value),
    );
  }
}

String _$recentFilesStoreHash() => r'81b3a5bec51f7832c0e40b233982adcd1347aa40';

/// The recent files loaded at start-up, which `bootstrap()` overrides, so
/// the first frame of the start screen already lists them.

@ProviderFor(initialRecentFiles)
final initialRecentFilesProvider = InitialRecentFilesProvider._();

/// The recent files loaded at start-up, which `bootstrap()` overrides, so
/// the first frame of the start screen already lists them.

final class InitialRecentFilesProvider
    extends
        $FunctionalProvider<
          List<RecentEntry>,
          List<RecentEntry>,
          List<RecentEntry>
        >
    with $Provider<List<RecentEntry>> {
  /// The recent files loaded at start-up, which `bootstrap()` overrides, so
  /// the first frame of the start screen already lists them.
  InitialRecentFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialRecentFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialRecentFilesHash();

  @$internal
  @override
  $ProviderElement<List<RecentEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<RecentEntry> create(Ref ref) {
    return initialRecentFiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<RecentEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<RecentEntry>>(value),
    );
  }
}

String _$initialRecentFilesHash() =>
    r'f00523a1a5891b3a68a630d5fa060962be6fca57';

/// The recent files, most recent first, as `recentFilesProvider`: every
/// file opened, at most [limit] of them besides the pinned ones. Each
/// change is stored at once; a failed save keeps the list for this session.

@ProviderFor(RecentFiles)
final recentFilesProvider = RecentFilesProvider._();

/// The recent files, most recent first, as `recentFilesProvider`: every
/// file opened, at most [limit] of them besides the pinned ones. Each
/// change is stored at once; a failed save keeps the list for this session.
final class RecentFilesProvider
    extends $NotifierProvider<RecentFiles, List<RecentEntry>> {
  /// The recent files, most recent first, as `recentFilesProvider`: every
  /// file opened, at most [limit] of them besides the pinned ones. Each
  /// change is stored at once; a failed save keeps the list for this session.
  RecentFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentFilesHash();

  @$internal
  @override
  RecentFiles create() => RecentFiles();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<RecentEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<RecentEntry>>(value),
    );
  }
}

String _$recentFilesHash() => r'd9217fde62a14057333a4718ca4f55c97cf9ba64';

/// The recent files, most recent first, as `recentFilesProvider`: every
/// file opened, at most [limit] of them besides the pinned ones. Each
/// change is stored at once; a failed save keeps the list for this session.

abstract class _$RecentFiles extends $Notifier<List<RecentEntry>> {
  List<RecentEntry> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<RecentEntry>, List<RecentEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<RecentEntry>, List<RecentEntry>>,
              List<RecentEntry>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
