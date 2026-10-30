import 'package:file_selector/file_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker_service.g.dart';

/// The OS-native file pickers (ADR 0018): every picker call goes through
/// it, as `filePickerServiceProvider`, and tests give it a fake.
abstract interface class FilePickerService {
  /// Shows the system open panel for PDF files, several at once (a1-13),
  /// its filter named [filterLabel]; the chosen paths, none when cancelled.
  Future<List<String>> openPdfs({required String filterLabel});
}

/// The pickers of file_selector: NSOpenPanel on macOS, IFileOpenDialog on
/// Windows, the GTK file chooser or the desktop portal on Linux.
final class NativeFilePickerService implements FilePickerService {
  /// The pickers of the running system.
  const new();

  @override
  Future<List<String>> openPdfs({required String filterLabel}) async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: filterLabel,
          extensions: const ['pdf'],
          mimeTypes: const ['application/pdf'],
          uniformTypeIdentifiers: const ['com.adobe.pdf'],
        ),
      ],
    );
    return [for (final file in files) file.path];
  }
}

/// The pickers, as `filePickerServiceProvider`.
@Riverpod(keepAlive: true)
FilePickerService filePickerService(Ref ref) => const NativeFilePickerService();
