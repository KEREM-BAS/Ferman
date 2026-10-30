import 'package:file_selector/file_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker_service.g.dart';

/// The OS-native file pickers (ADR 0018): every picker call goes through
/// it, as `filePickerServiceProvider`, and tests give it a fake.
abstract interface class FilePickerService {
  /// Shows the system open panel for PDF files, several at once (a1-13),
  /// its filter named [filterLabel]; the chosen paths, none when cancelled.
  Future<List<String>> openPdfs({required String filterLabel});

  /// Shows the system open panel for one PDF file, its filter named
  /// [filterLabel] ("Locate…" of a1-9e); the chosen path, null when
  /// cancelled.
  Future<String?> openPdf({required String filterLabel});
}

/// The pickers of file_selector: NSOpenPanel on macOS, IFileOpenDialog on
/// Windows, the GTK file chooser or the desktop portal on Linux.
final class NativeFilePickerService implements FilePickerService {
  /// The pickers of the running system.
  const new();

  @override
  Future<List<String>> openPdfs({required String filterLabel}) async {
    final files = await openFiles(acceptedTypeGroups: [_pdf(filterLabel)]);
    return [for (final file in files) file.path];
  }

  @override
  Future<String?> openPdf({required String filterLabel}) async {
    final file = await openFile(acceptedTypeGroups: [_pdf(filterLabel)]);
    return file?.path;
  }

  static XTypeGroup _pdf(String label) => XTypeGroup(
    label: label,
    extensions: const ['pdf'],
    mimeTypes: const ['application/pdf'],
    uniformTypeIdentifiers: const ['com.adobe.pdf'],
  );
}

/// The pickers, as `filePickerServiceProvider`.
@Riverpod(keepAlive: true)
FilePickerService filePickerService(Ref ref) => const NativeFilePickerService();
