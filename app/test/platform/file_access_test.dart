import 'package:ferman/platform/file_access.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ferman/files test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const access = PlatformFileAccess(channel);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('bookmark and access pass through the runner', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'bookmark' => 'b:${call.arguments}',
        'access' when call.arguments == 'stale' => {
          'path': '/moved/a.pdf',
          'renewed': 'fresh',
        },
        'access' => {'path': '/docs/a.pdf', 'renewed': null},
        _ => null,
      };
    });
    expect(await access.bookmark('/docs/a.pdf'), 'b:/docs/a.pdf');
    final held = await access.access('held');
    expect(held?.path, '/docs/a.pdf');
    expect(held?.renewed, isNull);
    final stale = await access.access('stale');
    expect(stale?.path, '/moved/a.pdf');
    expect(stale?.renewed, 'fresh');
  });

  test('a runner without a handler, or one that fails or answers nothing '
      'usable, gives null', () async {
    expect(await access.bookmark('/docs/a.pdf'), isNull);
    expect(await access.access('x'), isNull);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'broken'),
    );
    expect(await access.bookmark('/docs/a.pdf'), isNull);
    expect(await access.access('x'), isNull);
    messenger.setMockMethodCallHandler(channel, (call) async => {'path': ''});
    expect(await access.access('x'), isNull);
  });

  test('openUrl asks the runner; without a handler, or when it fails, it is '
      'false', () async {
    expect(await access.openUrl('https://example.org'), isFalse);
    final urls = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openUrl');
      urls.add(call.arguments);
      return true;
    });
    expect(await access.openUrl('https://example.org'), isTrue);
    expect(urls, ['https://example.org']);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'broken'),
    );
    expect(await access.openUrl('https://example.org'), isFalse);
  });

  test('release and show pass the path to the runner; without a handler, '
      'or when it fails, show is false', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'show' ? true : null;
    });
    await access.release('/docs/a.pdf');
    expect(await access.show('/docs/a.pdf'), isTrue);
    expect(
      [for (final call in calls) (call.method, call.arguments)],
      [('release', '/docs/a.pdf'), ('show', '/docs/a.pdf')],
    );

    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await access.show('/docs/a.pdf'), isFalse);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'broken'),
    );
    await access.release('/docs/a.pdf');
    expect(await access.show('/docs/a.pdf'), isFalse);
    messenger.setMockMethodCallHandler(channel, null);
    await access.release('/docs/a.pdf');
    expect(await access.show('/docs/a.pdf'), isFalse);
  });
}
