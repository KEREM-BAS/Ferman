import 'dart:io';

import 'package:l10n/l10n.dart';

/// Renders the translation table of `docs/TRANSLATION_REVIEW.md` from the
/// ARB files in `app/lib/l10n/`.
///
/// Usage, from `tools/l10n`: `dart run l10n:review_table [--root <dir>]
/// [--check]`. `--check` writes nothing and exits with 1 when the table is
/// stale.
Future<void> main(List<String> arguments) async {
  exitCode = await runReviewTableCli(arguments, out: stdout, err: stderr);
}
