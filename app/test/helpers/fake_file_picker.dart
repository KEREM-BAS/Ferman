import 'package:ferman/platform/file_picker_service.dart';

/// A [FilePickerService] that answers the open panel with [picked] and
/// logs each filter it was asked for in [requests].
final class FakeFilePickerService implements FilePickerService {
  /// Picks [picked] each time; nothing by default, as if cancelled.
  new({this.picked = const []});

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
}
