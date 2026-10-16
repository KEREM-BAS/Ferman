/// **Proposed** (ROADMAP §5 step 10): the editor shell renders in the
/// pseudo-locale, with strings 40% longer, without clipping or overflow
/// errors, in all eight modes, at the boards' 1440 × 900 and the 1024 × 768
/// least width (G21), under the macOS and the Windows title bar. It stands
/// in for German, which the boards a12-2b and a12-2d draw only for the
/// start screen and Settings (`pseudo_locale_test.dart` checks those).
///
/// The shell frees room as G21 decides: tool labels hide behind their
/// icons, tools move into the "More tools" menu and the mode tabs fall back
/// to icons. A hidden label leaves the tree, so what is left on screen must
/// fit.
library;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../features/shell/shell_host.dart';
import '../helpers/fake_desktop_window.dart';
import '../helpers/m1_screens.dart';
import '../helpers/pseudo_locale.dart';
import '../helpers/text_fit.dart';

/// Texts the design truncates too: the value of a select (the zoom menu),
/// which the boards draw as a one-line `<select>` that clips, and the file
/// name of a document tab, which FmWindow ends with an ellipsis and gives
/// in full as the tab's tooltip (line 23, `title`). File names are data,
/// the same in every language.
bool _truncatesInDesign(Element text) => hasAncestor(
  text,
  (widget) => widget is Select || widget is TextField || widget is DocumentTab,
);

void main() {
  final pseudo = PseudoLocalizations.fromArb();
  late FakeDesktopWindow window;

  tearDown(() => window.dispose());

  for (final size in m1WindowSizes) {
    for (final (chrome, keys) in [
      (WindowPlatform.mac, ShortcutPlatform.mac),
      (WindowPlatform.win, ShortcutPlatform.windows),
    ]) {
      testWidgets('the shell in every mode at ${sizeName(size)}, '
          '${chrome.name}', (tester) async {
        window = FakeDesktopWindow(chrome);
        final sizes = ValueNotifier(size);
        addTearDown(sizes.dispose);
        final opening = await collectFlutterErrors(
          () => pumpShellAt(
            tester,
            shellHost(
              window: window,
              platform: keys,
              size: sizes,
              localizations: PseudoLocalizationsDelegate(pseudo),
            ),
            sizes,
          ),
        );
        expect(describeErrors(opening), isEmpty, reason: 'overflow errors');
        final container = containerOf(tester);
        for (final mode in FermanMode.values) {
          final errors = await collectFlutterErrors(() async {
            container.read(shellModeProvider.notifier).select(mode);
            await settle(tester);
          });
          expect(describeErrors(errors), isEmpty, reason: '${mode.id}: errors');
          // The pseudo-locale is in force …
          expect(find.textContaining(pseudoStart), findsWidgets);
          // … and every text left on screen fits.
          expect(
            textFitProblems(
              tester,
              allowed: _truncatesInDesign,
            ).map((problem) => '$problem'),
            isEmpty,
            reason: '${mode.id}: texts that do not fit',
          );
        }
      });
    }
  }
}
