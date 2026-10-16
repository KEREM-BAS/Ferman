import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the accessibility announcements the app sends while the test
/// runs: the data of each `announce` event (`message`, `assertiveness`, …).
List<Map<Object?, Object?>> recordAnnouncements(WidgetTester tester) {
  final log = <Map<Object?, Object?>>[];
  final messenger = tester.binding.defaultBinaryMessenger
    ..setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
      message,
    ) async {
      final event = message! as Map<Object?, Object?>;
      if (event['type'] == 'announce') {
        log.add(event['data']! as Map<Object?, Object?>);
      }
      return null;
    });
  addTearDown(
    () => messenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      null,
    ),
  );
  return log;
}

/// [child] on a platform that supports announcements
/// ([MediaQueryData.supportsAnnounce]), as the desktop systems do.
Widget withAnnouncements(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(supportsAnnounce: true),
    child: child,
  ),
);
