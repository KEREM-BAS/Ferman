/// ROADMAP §5 step 9: settings are stored only in the app data directory;
/// nothing leaves the device.
library;

import 'dart:io';

import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_start.dart';
import 'package:ferman/settings/settings_store_io.dart' show FileSettingsStore;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The channel `path_provider` asks for its directories on in tests: no
/// desktop implementation is registered there, so the package's method
/// channel answers (`MethodChannelPathProvider`).
const MethodChannel _pathProvider = MethodChannel(
  'plugins.flutter.io/path_provider',
);

/// Records every file and link the code under it names and every network
/// connection it tries; a connection fails.
final class _DeviceOnlyOverrides extends IOOverrides {
  final List<String> files = [];
  final List<String> connections = [];

  @override
  File createFile(String path) {
    files.add(path);
    return super.createFile(path);
  }

  @override
  Link createLink(String path) {
    files.add(path);
    return super.createLink(path);
  }

  @override
  Future<Socket> socketConnect(
    Object? host,
    int port, {
    Object? sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    connections.add('$host:$port');
    throw const SocketException('settings must not connect');
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    Object? host,
    int port, {
    Object? sourceAddress,
    int sourcePort = 0,
  }) {
    connections.add('$host:$port');
    throw const SocketException('settings must not connect');
  }

  @override
  Future<ServerSocket> serverSocketBind(
    Object? address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) {
    connections.add('bind $address:$port');
    throw const SocketException('settings must not listen');
  }
}

/// Records every HTTP client the code under it creates.
final class _NoHttpOverrides extends HttpOverrides {
  int clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return super.createHttpClient(context);
  }
}

/// [source] without its `//` comments, so prose does not count as code.
String _code(String source) => [
  for (final line in source.split('\n'))
    if (line.indexOf('//') case final start when start >= 0)
      line.substring(0, start)
    else
      line,
].join('\n');

/// The URIs of every `import` and `export` directive in [code]: whole
/// directives up to their `;`, so the URIs of a conditional directive's
/// later lines count too, single or double quoted.
List<String> _directiveUris(String code) => [
  for (final directive in RegExp(
    r'^\s*(import|export)\b[^;]*;',
    multiLine: true,
  ).allMatches(code))
    for (final uri in RegExp('''['"]([^'"]*)['"]''').allMatches(directive[0]!))
      uri[1]!,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the settings store lives in the app support directory', () {
    late Directory root;
    late Directory support;
    late List<String> asked;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ferman_on_device_');
      // Not created yet, as on a first start.
      support = Directory('${root.path}${Platform.pathSeparator}support');
      asked = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProvider, (call) async {
            asked.add(call.method);
            return switch (call.method) {
              'getApplicationSupportDirectory' => support.path,
              // Any other directory would be a place outside the app's own.
              _ => '${root.path}${Platform.pathSeparator}${call.method}',
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProvider, null);
      root.deleteSync(recursive: true);
    });

    test(
      'the app’s store asks only for the app support directory, and a '
      'save writes only settings.json there, through its temporary file',
      () async {
        final io = _DeviceOnlyOverrides();
        final http = _NoHttpOverrides();
        Future<T> deviceOnly<T>(Future<T> Function() body) =>
            HttpOverrides.runWithHttpOverrides(
              () => IOOverrides.runWithIOOverrides(body, io),
              http,
            );

        // As `bootstrap()` opens it. Where the store points is checked
        // before anything is saved, so a store that got past the stub never
        // writes over a real settings.json.
        final store = await deviceOnly(openSettingsStore);
        expect(asked, ['getApplicationSupportDirectory']);
        expect(store, isA<FileSettingsStore>());
        expect((store as FileSettingsStore).directory.path, support.path);
        // Opening writes nothing.
        expect(support.existsSync(), isFalse);

        const settings = AppSettings(
          themeMode: AppThemeMode.dark,
          languageCode: 'tr',
          regionCode: 'TR',
          onboardingCompleted: true,
        );
        await deviceOnly(() => store.save(settings));
        expect(await deviceOnly(store.load), settings);
        expect(asked, ['getApplicationSupportDirectory']);

        // Every file it named is settings.json or the temporary file the
        // save renames over it, in that directory …
        final file =
            '${support.path}${Platform.pathSeparator}'
            '${FileSettingsStore.fileName}';
        expect(io.files.toSet(), {file, '$file.tmp'});
        // … and afterwards only settings.json is there, and nothing else
        // beside the directory.
        List<String> names(Directory directory) => [
          for (final entry in directory.listSync())
            entry.uri.pathSegments.where((part) => part.isNotEmpty).last,
        ];
        expect(names(support), [FileSettingsStore.fileName]);
        expect(names(root), ['support']);

        // Nothing tried to leave the device.
        expect(io.connections, isEmpty);
        expect(http.clients, 0);
      },
    );
  });

  group('no settings code can reach the network', () {
    test('the directive check reads whole directives, in either quote', () {
      const sample = '''
export 'package:ferman/a.dart'
    if (dart.library.js_interop) 'package:web/web.dart'
    show a;
import "dart:html";
  import 'package:http/http.dart' as http;
''';
      expect(_directiveUris(_code(sample)), [
        'package:ferman/a.dart',
        'package:web/web.dart',
        'dart:html',
        'package:http/http.dart',
      ]);
    });

    test('no file under lib/settings/ or lib/features/settings/ imports a '
        'network or browser library or names a network class', () {
      const forbiddenImports = [
        'package:http/',
        'dart:html',
        'package:web/',
        'dart:js_interop',
      ];
      final forbiddenNames = RegExp(
        r'\b(HttpClient|HttpServer|HttpRequest|(Raw|Secure)?(Server)?Socket|'
        r'WebSocket|RawDatagramSocket)\b',
      );
      final files = [
        for (final path in ['lib/settings', 'lib/features/settings'])
          ...Directory(path)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart')),
      ];
      expect(
        files.map((file) => file.uri.pathSegments.last),
        containsAll(['settings_store_io.dart', 'settings_store_web.dart']),
      );
      for (final file in files) {
        final code = _code(file.readAsStringSync());
        final uris = _directiveUris(code);
        // The conditional export of settings_start.dart is read whole.
        if (file.path.endsWith('settings_start.dart')) {
          expect(
            uris,
            containsAll([
              'package:ferman/settings/settings_store_io.dart',
              'package:ferman/settings/settings_store_web.dart',
            ]),
          );
        }
        for (final uri in uris) {
          for (final forbidden in forbiddenImports) {
            expect(
              uri.startsWith(forbidden),
              isFalse,
              reason: '${file.path}: $uri',
            );
          }
        }
        expect(
          forbiddenNames.allMatches(code).map((match) => match.group(0)),
          isEmpty,
          reason: file.path,
        );
      }
    });
  });
}
