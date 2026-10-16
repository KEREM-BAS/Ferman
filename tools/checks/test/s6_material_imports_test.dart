import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

List<S6Finding> _findings(String path, String code) =>
    S6MaterialImportsCheck.findings(DartSource(path, code));

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const S6MaterialImportsCheck()), skips);
  });

  test('allows the design system and app.dart only', () {
    const material = "import 'package:flutter/material.dart';\n";
    final fixture = Fixture()
      ..write('app/lib/app/app.dart', material)
      ..write('app/lib/design/theme/theme_scope.dart', material)
      ..write('app/lib/design/components/button.dart', material)
      ..write('app/lib/app/router.g.dart', material)
      ..write('app/lib/features/start/start_screen.dart', material)
      ..write('app/lib/app/bootstrap.dart', material);
    final result = fixture.run(const S6MaterialImportsCheck(allowlist: []));
    const expected =
        'app/lib/features/start/start_screen.dart:1: imports '
        'package:flutter/material.dart; only app/lib/design/ and '
        'app/lib/app/app.dart may';
    expect(result, failsWith([expected]));
    expect(result, failsWith(['app/lib/app/bootstrap.dart:1']));
    final reported = {
      for (final message in result.messages)
        if (message.startsWith('app/lib/')) message.split(':').first,
    };
    expect(reported, {
      'app/lib/features/start/start_screen.dart',
      'app/lib/app/bootstrap.dart',
    });
  });

  test('passes when Material is imported only where allowed', () {
    final fixture = Fixture()
      ..write(
        'app/lib/app/app.dart',
        "import 'package:flutter/material.dart';\n",
      )
      ..write(
        'app/lib/features/a.dart',
        "import 'package:flutter/widgets.dart';\n"
            "// import 'package:flutter/material.dart';\n"
            "const s = \"import 'package:flutter/material.dart';\";\n",
      );
    expect(fixture.run(const S6MaterialImportsCheck(allowlist: [])), passes);
  });

  test('catches Cupertino, sub-libraries, prefixes and show clauses', () {
    for (final directive in [
      "import 'package:flutter/cupertino.dart';",
      "import 'package:flutter/src/material/colors.dart';",
      "import 'package:flutter/src/cupertino/colors.dart';",
      "import 'package:flutter/material.dart' as m;",
      "import 'package:flutter/material.dart' show ThemeMode;",
      'import "package:flutter/material.dart" hide Tooltip;',
    ]) {
      expect(
        _findings('app/lib/features/a.dart', directive).map((f) => f.rule),
        ['import'],
        reason: directive,
      );
    }
  });

  test('re-exports are findings everywhere, the design system included', () {
    expect(
      _findings(
        'app/lib/design/theme.dart',
        "export 'package:flutter/material.dart' show ThemeMode;",
      ).map((f) => f.rule),
      ['export'],
    );
    expect(
      _findings(
        'app/lib/design/theme.dart',
        "export 'package:ferman/design/tokens.g.dart';",
      ),
      isEmpty,
    );
  });

  test('isMaterialUri and mayImport', () {
    expect(
      S6MaterialImportsCheck.isMaterialUri('package:flutter/widgets.dart'),
      isFalse,
    );
    expect(
      S6MaterialImportsCheck.isMaterialUri(
        'package:flutter_localizations/flutter_localizations.dart',
      ),
      isFalse,
    );
    expect(S6MaterialImportsCheck.mayImport('app/lib/app/app.dart'), isTrue);
    expect(S6MaterialImportsCheck.mayImport('app/lib/app/app2.dart'), isFalse);
    expect(S6MaterialImportsCheck.mayImport('app/lib/designer.dart'), isFalse);
  });
}
