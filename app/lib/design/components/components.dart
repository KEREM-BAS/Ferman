/// The Ferman component library: the design system's components in
/// Flutter, with the same names, variants and states (ADR 0011,
/// `docs/COMPONENTS.md`).
///
/// Several names are also framework names (`Icon`, `Tooltip`, `IconButton`,
/// `Badge`, `Radio`, `Switch`, `TextField`, `Checkbox`, `Dialog`,
/// `Banner`): files that use this library import
/// `package:flutter/widgets.dart` with `hide` for the ones they use.
library;

export 'package:ferman/design/components/core/kbd.dart';
export 'package:ferman/design/components/core/tooltip.dart';
export 'package:ferman/design/components/foundation/anchored_layout.dart';
export 'package:ferman/design/components/foundation/focus_ring.dart';
export 'package:ferman/design/components/foundation/forced_states.dart';
export 'package:ferman/design/components/foundation/future_version.dart';
export 'package:ferman/design/components/foundation/interactive.dart';
export 'package:ferman/design/icons/icon.dart';
