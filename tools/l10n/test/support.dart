import 'dart:io';

import 'package:l10n/l10n.dart';
import 'package:path/path.dart' as p;

/// The repository root: the nearest parent of the working directory that
/// holds `app/l10n.yaml` and `tools/l10n/`.
final String repoRoot = () {
  var directory = Directory.current.absolute.path;
  while (true) {
    if (File(p.join(directory, 'app', 'l10n.yaml')).existsSync() &&
        File(p.join(directory, 'tools', 'l10n', 'pubspec.yaml')).existsSync()) {
      return directory;
    }
    final parent = p.dirname(directory);
    if (parent == directory) {
      throw StateError('run the tests inside the Ferman repository');
    }
    directory = parent;
  }
}();

/// The gen-l10n output of this checkout.
String readInput() =>
    File(p.joinAll([repoRoot, ...inputPath.split('/')])).readAsStringSync();

/// A fresh temporary root holding `app/l10n.yaml` and [input] (the real
/// gen-l10n output by default) as the generator's input.
Directory tempRoot({String? input}) {
  final temp = Directory.systemTemp.createTempSync('ferman_l10n_');
  File(p.join(repoRoot, 'app', 'l10n.yaml')).copySync(
    (File(
      p.join(temp.path, 'app', 'l10n.yaml'),
    )..parent.createSync(recursive: true)).path,
  );
  File(p.joinAll([temp.path, ...inputPath.split('/')]))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(input ?? readInput());
  return temp;
}

/// A gen-l10n-like file whose abstract class has [members].
String classWith(String members) =>
    '''
import 'package:flutter/widgets.dart';

abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = locale;

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

$members
}

class _AppLocalizationsDelegate {
  String get notAMember => 'x';
}
''';
