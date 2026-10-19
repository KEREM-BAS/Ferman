import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// The disabled reason of every control whose feature is not built yet:
/// the localized "Available in a future version" (brief, G10).
///
/// Screens never call it themselves: each control names its feature in the
/// feature registry (`Feature` in `app/lib/app/feature_registry.dart`) and
/// passes `Feature.disabledReason`, which returns this reason while the
/// feature is unavailable; the feature has a row in `docs/BACKLOG.md`.
/// Components of this library use it for their own parts that wait for a
/// callback, and the gallery for its samples (`tools/checks`
/// `feature_registry`).
String futureVersionReason(BuildContext context) =>
    AppLocalizations.of(context).availableInFutureVersion;
