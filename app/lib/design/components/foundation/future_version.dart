import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// The disabled reason of every control whose feature is not built yet:
/// the localized "Available in a future version" (brief, G10).
///
/// Pass it as the component's `disabledReason`; the control stays visible
/// as designed, disabled, and the feature gets a row in `docs/BACKLOG.md`.
String futureVersionReason(BuildContext context) =>
    AppLocalizations.of(context).availableInFutureVersion;
