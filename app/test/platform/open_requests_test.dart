import 'package:ferman/platform/open_requests.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ferman/open test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Calls [method] on Dart as the runner would, returning the reply.
  Future<ByteData?> fromRunner(String method, Object? arguments) =>
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('the launch is the command line, then what the runner kept', () async {
    final asked = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked.add(call.method);
      return ['/kept/a.pdf', '', 3];
    });
    final requests = await PlatformOpenRequests.start(['/args/b.pdf'], channel);
    addTearDown(requests.dispose);
    expect(asked, ['ready']);
    expect(requests.launch, ['/args/b.pdf', '/kept/a.pdf']);
  });

  test('a runner without a handler asks for nothing more', () async {
    final requests = await PlatformOpenRequests.start(['/args/b.pdf'], channel);
    addTearDown(requests.dispose);
    expect(requests.launch, ['/args/b.pdf']);
  });

  test('a runner that fails keeps nothing back', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'broken'),
    );
    final requests = await PlatformOpenRequests.start(const [], channel);
    addTearDown(requests.dispose);
    expect(requests.launch, isEmpty);
  });

  test('later requests arrive in order; empty ones and other methods are '
      'not requests', () async {
    final requests = await PlatformOpenRequests.start(const [], channel);
    final later = <List<String>>[];
    final subscription = requests.later.listen(later.add);
    addTearDown(() async {
      await subscription.cancel();
      requests.dispose();
    });
    await fromRunner('open', ['/docs/a.pdf', '/docs/b.pdf']);
    await fromRunner('open', <String>[]);
    await fromRunner('open', 'not a list');
    await fromRunner('focus', ['/docs/c.pdf']);
    await fromRunner('open', ['/docs/c.pdf']);
    await pumpEventQueue();
    expect(later, [
      ['/docs/a.pdf', '/docs/b.pdf'],
      ['/docs/c.pdf'],
    ]);
  });
}
