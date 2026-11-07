import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/platform/print_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ferman/print test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const printer = PlatformPrintService(channel);
  final page = PrintPage(
    index: 4,
    widthPoints: 595.28,
    heightPoints: 841.89,
    dpi: 300,
    width: 1,
    height: 1,
    pixels: Uint8List.fromList(const [255, 255, 255, 255]),
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a page goes with its place in the print; true is the next one, a '
      'number the one the runner wants (Linux)', () async {
    Object? answer = true;
    final asked = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked.add((call.arguments as Map<Object?, Object?>)['index']);
      return answer;
    });
    expect(await printer.page(page, at: 2), 3);
    answer = 0;
    expect(await printer.page(page, at: 2), 0);
    answer = false;
    expect(await printer.page(page, at: 2), isNull);
    expect(asked, [2, 2, 2]);
  });

  test(
    'a runner without a handler, or one that fails, stops the print',
    () async {
      expect(await printer.page(page, at: 0), isNull);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'broken'),
      );
      expect(await printer.page(page, at: 0), isNull);
    },
  );
}
