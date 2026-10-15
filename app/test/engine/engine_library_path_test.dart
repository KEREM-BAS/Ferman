import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/engine_service_frb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bundledEngineLibraryPath', () {
    test('Linux: lib/ beside the executable, as the bundle installs it', () {
      expect(
        bundledEngineLibraryPath(
          executable: '/opt/ferman/ferman',
          operatingSystem: 'linux',
        ),
        '/opt/ferman/lib/libferman_api.so',
      );
    });

    test('Windows: the DLL next to ferman.exe', () {
      expect(
        bundledEngineLibraryPath(
          executable: r'C:\Program Files\Ferman\ferman.exe',
          operatingSystem: 'windows',
        ),
        r'C:\Program Files\Ferman\ferman_api.dll',
      );
    });

    test(
      'macOS: the rust_lib_ferman plugin framework in Contents/Frameworks',
      () {
        expect(
          bundledEngineLibraryPath(
            executable: '/Applications/Ferman.app/Contents/MacOS/Ferman',
            operatingSystem: 'macos',
          ),
          '/Applications/Ferman.app/Contents/MacOS/../Frameworks/'
          'rust_lib_ferman.framework/rust_lib_ferman',
        );
      },
    );

    test('never depends on the current directory', () {
      final path = bundledEngineLibraryPath(
        executable: '/opt/ferman/ferman',
        operatingSystem: 'linux',
      );
      expect(path, startsWith('/opt/ferman/'));
      expect(path, isNot(contains('target')));
    });

    test('other systems are unsupported', () {
      expect(
        () => bundledEngineLibraryPath(
          executable: '/system/bin/ferman',
          operatingSystem: 'android',
        ),
        throwsA(
          isA<EngineUnavailableException>().having(
            (e) => e.reason,
            'reason',
            EngineUnavailableReason.unsupportedPlatform,
          ),
        ),
      );
    });
  });
}
