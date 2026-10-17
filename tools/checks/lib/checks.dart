/// Repository checks for Ferman.
///
/// Each check inspects the repository and passes, fails, or is skipped when
/// its input does not exist yet. `bin/check_all.dart` runs them all; CI runs
/// it in the repo-checks job. The `s6_*` checks enforce the Flutter
/// conventions of brief §6 in `app/lib/`: Material imports, forbidden
/// dialog and tab APIs, literal colours and sizes, directional layout and
/// locale-aware casing, with reviewed exceptions in `s6_allowlist.dart`.
library;

export 'src/check.dart';
export 'src/checks/action_pins.dart';
export 'src/checks/arb_parity.dart';
export 'src/checks/bridge_imports.dart';
export 'src/checks/build_untracked.dart';
export 'src/checks/component_spec.dart';
export 'src/checks/crate_graph.dart';
export 'src/checks/dco_signoff.dart';
export 'src/checks/design_untouched.dart';
export 'src/checks/frb_versions.dart';
export 'src/checks/pub_denylist.dart';
export 'src/checks/s6_allowlist.dart';
export 'src/checks/s6_casing.dart';
export 'src/checks/s6_directional.dart';
export 'src/checks/s6_forbidden_api.dart';
export 'src/checks/s6_literals.dart';
export 'src/checks/s6_material_imports.dart';
export 'src/checks/s6_source.dart';
export 'src/checks/unsafe_roots.dart';
export 'src/checks/version_sync.dart';
export 'src/runner.dart';
