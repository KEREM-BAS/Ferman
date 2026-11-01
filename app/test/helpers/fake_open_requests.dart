import 'dart:async';

import 'package:ferman/platform/open_requests.dart';

/// [OpenRequests] that a test makes: the files of [launch], then each list
/// added to [requests].
final class FakeOpenRequests implements OpenRequests {
  /// Starts with [launch]; nothing by default.
  new({this.launch = const []});

  @override
  final List<String> launch;

  /// Where a test adds later requests.
  final StreamController<List<String>> requests = StreamController();

  @override
  Stream<List<String>> get later => requests.stream;

  /// Ends [requests].
  void close() => unawaited(requests.close());
}
