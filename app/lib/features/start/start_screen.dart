import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// The start screen. M1 step 9 replaces this placeholder with the empty start
/// screen of board a1-5.
class StartScreen extends StatelessWidget {
  /// Creates the start screen.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(child: Text(l10n.startPlaceholderTitle));
  }
}
