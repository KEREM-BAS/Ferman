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

  /// Shows the system save panel with [suggestedName] ("Save attachment
  /// as…", a2-3b); the chosen path, null when cancelled. The panel asks
  /// before replacing a file.
  Future<String?> saveFile({required String suggestedName});

  /// Shows the system open panel for files Combine and Create PDF take, several
  /// at once (a6-3), its filter named [filterLabel]; the chosen paths, none
  /// when cancelled.
  Future<List<String>> openFilesToCombine({required String filterLabel});

  /// Shows the system folder panel at [initial] (a6-2's Save to); the chosen
  /// folder, null when cancelled. Under the macOS sandbox it grants the
  /// folder for the session (G143).
  Future<String?> chooseFolder({String? initial});
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

  @override
  Future<String?> saveFile({required String suggestedName}) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    return location?.path;
  }

  @override
  Future<List<String>> openFilesToCombine({required String filterLabel}) async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: filterLabel,
          extensions: const [
            'pdf',
            'png',
            'jpg',
            'jpeg',
            'tif',
            'tiff',
            'webp',
            'gif',
            'doc',
            'docx',
            'odt',
            'xls',
            'xlsx',
            'ods',
          ],
          uniformTypeIdentifiers: const [
            'com.adobe.pdf',
            'public.image',
            'com.microsoft.word.doc',
            'org.openxmlformats.wordprocessingml.document',
            'org.oasis-open.opendocument.text',
            'com.microsoft.excel.xls',
            'org.openxmlformats.spreadsheetml.sheet',
            'org.oasis-open.opendocument.spreadsheet',
          ],
        ),
      ],
    );
    return [for (final file in files) file.path];
  }

  @override
  Future<String?> chooseFolder({String? initial}) =>
      getDirectoryPath(initialDirectory: initial);

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
