// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform's bookmarks, as `fileAccessProvider`; `bootstrap()` gives
/// the runner's.

@ProviderFor(fileAccess)
final fileAccessProvider = FileAccessProvider._();

/// The platform's bookmarks, as `fileAccessProvider`; `bootstrap()` gives
/// the runner's.

final class FileAccessProvider
    extends $FunctionalProvider<FileAccess, FileAccess, FileAccess>
    with $Provider<FileAccess> {
  /// The platform's bookmarks, as `fileAccessProvider`; `bootstrap()` gives
  /// the runner's.
  FileAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileAccessHash();

  @$internal
  @override
  $ProviderElement<FileAccess> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileAccess create(Ref ref) {
    return fileAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileAccess>(value),
    );
  }
}

String _$fileAccessHash() => r'841cc710748061c192353f419820ca788ba408e1';
