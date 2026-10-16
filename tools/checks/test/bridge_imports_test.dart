import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const BridgeImportsCheck()), skips);
  });

  test('allows app/lib/engine/ and the generated bridge itself', () {
    final fixture = Fixture()
      ..write(
        'app/lib/engine/engine_service_frb.dart',
        "import 'package:ferman/bridge/frb_generated.dart';\n"
            "import '../bridge/frb.dart' as bridge;\n",
      )
      ..write(
        'app/lib/bridge/frb_generated.dart',
        "import 'frb.dart';\n"
            "export 'package:ferman/bridge/frb.dart';\n",
      )
      ..write(
        'app/lib/app/bootstrap.dart',
        "import 'package:ferman/engine/engine_start.dart';\n"
            "// import 'package:ferman/bridge/frb.dart';\n"
            "const s = \"import 'package:ferman/bridge/frb.dart';\";\n",
      );
    expect(fixture.run(const BridgeImportsCheck()), passes);
  });

  test('fails on package, relative and conditional URIs elsewhere', () {
    final fixture = Fixture()
      ..write(
        'app/lib/features/start/start_screen.dart',
        "import 'package:flutter/widgets.dart';\n"
            "import 'package:ferman/bridge/frb.dart';\n",
      )
      ..write(
        'app/lib/app/bootstrap.dart',
        "import '../bridge/frb_generated.dart' as b;\n",
      )
      ..write(
        'app/lib/app/start.dart',
        "import 'stub.dart'\n"
            "    if (dart.library.io) 'package:ferman/bridge/frb.dart';\n",
      )
      ..write(
        'app/lib/design/barrel.dart',
        "export 'package:ferman/bridge/frb.dart' show EngineInfo;\n",
      )
      ..write(
        'app/test/engine/engine_test.dart',
        "import 'package:ferman/bridge/frb_generated.dart';\n",
      )
      ..write(
        'app/integration_test/app_test.dart',
        "import 'package:ferman/bridge/frb.dart';\n",
      );
    final result = fixture.run(const BridgeImportsCheck());
    const fullMessage =
        'app/lib/features/start/start_screen.dart:2: imports '
        'package:ferman/bridge/frb.dart; only app/lib/engine/ may use the '
        'bridge, go through EngineService instead';
    expect(
      result,
      failsWith([
        fullMessage,
        'app/lib/app/bootstrap.dart:1: imports ../bridge/frb_generated.dart',
        'app/lib/app/start.dart:1: imports package:ferman/bridge/frb.dart',
        'app/lib/design/barrel.dart:1: exports package:ferman/bridge/frb.dart',
        'app/test/engine/engine_test.dart:1: imports',
        'app/integration_test/app_test.dart:1: imports',
      ]),
    );
    expect(result.messages, hasLength(6));
  });

  test('a relative URI that only looks like the bridge passes', () {
    expect(
      BridgeImportsCheck.isBridgeUri(
        'app/lib/features/bridge_view.dart',
        'bridge/frb.dart',
      ),
      isFalse,
    );
    expect(
      BridgeImportsCheck.isBridgeUri('app/lib/a/b.dart', '../../lib/x.dart'),
      isFalse,
    );
    expect(
      BridgeImportsCheck.isBridgeUri('app/lib/a/b.dart', '../bridge/frb.dart'),
      isTrue,
    );
    expect(
      BridgeImportsCheck.isBridgeUri(
        'app/lib/a.dart',
        'package:rust_lib_ferman/x.dart',
      ),
      isFalse,
    );
  });
}
