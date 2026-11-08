import 'dart:typed_data';

import 'package:ferman/platform/file_picker_service.dart';

/// A [FilePickerService] that answers the open panel with [picked] and
/// logs each filter it was asked for in [requests].
final class FakeFilePickerService implements FilePickerService {
  /// Picks [picked] each time; nothing by default, as if cancelled.
  new({this.picked = const [], this.saveTo});

  /// The paths the open panel returns.
  List<String> picked;

  /// The filter label of each open panel shown.
  final List<String> requests = [];

  @override
  Future<List<String>> openPdfs({required String filterLabel}) async {
    requests.add(filterLabel);
    return picked;
  }

  /// The first of [picked], as the one-file panel answers.
  @override
  Future<String?> openPdf({required String filterLabel}) async {
    requests.add(filterLabel);
    return picked.isEmpty ? null : picked.first;
  }

  /// The name each save panel suggested, oldest first.
  final List<String> saves = [];

  /// The path the save panel returns; null, as if cancelled, by default.
  String? saveTo;

  @override
  Future<String?> saveFile({required String suggestedName}) async {
    saves.add(suggestedName);
    return saveTo;
  }

  @override
  Future<List<String>> openFilesToCombine({required String filterLabel}) async {
    requests.add(filterLabel);
    return picked;
  }

  /// The first of [picked], as the any-file panel answers; logged as `*`.
  @override
  Future<String?> openAnyFile() async {
    requests.add('*');
    return picked.isEmpty ? null : picked.first;
  }

  /// What the folder panel returns; null, as if cancelled, by default.
  String? folder;

  @override
  Future<String?> chooseFolder({String? initial}) async => folder;

  /// What the stamp's open panel returns; null, as if cancelled, by default.
  Uint8List? stampFile;

  @override
  Future<Uint8List?> openStamp({
    required String filterLabel,
    required String extension,
    required int largest,
  }) async {
    requests.add(filterLabel);
    return stampFile;
  }

  /// What the image's open panel returns; null, as if cancelled, by default.
  Uint8List? imageFile;

  @override
  Future<Uint8List?> openImage({
    required String filterLabel,
    required int largest,
  }) async {
    requests.add(filterLabel);
    return imageFile;
  }

  /// The files written, by path.
  final Map<String, Uint8List> written = {};

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    written[path] = bytes;
  }
}
