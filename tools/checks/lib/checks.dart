/// Repository checks for Ferman.
///
/// Each check inspects the repository and passes, fails, or is skipped when
/// its input does not exist yet. `bin/check_all.dart` runs them all; CI runs
/// it in the repo-checks job.
library;

export 'src/check.dart';
export 'src/checks/action_pins.dart';
export 'src/checks/arb_parity.dart';
export 'src/checks/build_untracked.dart';
export 'src/checks/crate_graph.dart';
export 'src/checks/design_untouched.dart';
export 'src/checks/frb_versions.dart';
export 'src/checks/pub_denylist.dart';
export 'src/checks/unsafe_roots.dart';
export 'src/checks/version_sync.dart';
export 'src/runner.dart';
