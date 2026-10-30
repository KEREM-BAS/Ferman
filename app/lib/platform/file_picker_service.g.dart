// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_picker_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pickers, as `filePickerServiceProvider`.

@ProviderFor(filePickerService)
final filePickerServiceProvider = FilePickerServiceProvider._();

/// The pickers, as `filePickerServiceProvider`.

final class FilePickerServiceProvider
    extends
        $FunctionalProvider<
          FilePickerService,
          FilePickerService,
          FilePickerService
        >
    with $Provider<FilePickerService> {
  /// The pickers, as `filePickerServiceProvider`.
  FilePickerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filePickerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filePickerServiceHash();

  @$internal
  @override
  $ProviderElement<FilePickerService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FilePickerService create(Ref ref) {
    return filePickerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilePickerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilePickerService>(value),
    );
  }
}

String _$filePickerServiceHash() => r'8bb7a961c7bc9d5067e037c4c6b33f1dd619053e';
