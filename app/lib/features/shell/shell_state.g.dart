// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The mode shown, as `shellModeProvider`. Modes are state, not routes
/// (ADR 0011); the shell shows each mode's tool row in an `IndexedStack`,
/// so a mode keeps its state while another is shown.
///
/// A document opens in View, the first mode.

@ProviderFor(ShellMode)
final shellModeProvider = ShellModeProvider._();

/// The mode shown, as `shellModeProvider`. Modes are state, not routes
/// (ADR 0011); the shell shows each mode's tool row in an `IndexedStack`,
/// so a mode keeps its state while another is shown.
///
/// A document opens in View, the first mode.
final class ShellModeProvider extends $NotifierProvider<ShellMode, FermanMode> {
  /// The mode shown, as `shellModeProvider`. Modes are state, not routes
  /// (ADR 0011); the shell shows each mode's tool row in an `IndexedStack`,
  /// so a mode keeps its state while another is shown.
  ///
  /// A document opens in View, the first mode.
  ShellModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellModeHash();

  @$internal
  @override
  ShellMode create() => ShellMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FermanMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FermanMode>(value),
    );
  }
}

String _$shellModeHash() => r'1cf2a93910316961678bfe4efe0c99c509e80bab';

/// The mode shown, as `shellModeProvider`. Modes are state, not routes
/// (ADR 0011); the shell shows each mode's tool row in an `IndexedStack`,
/// so a mode keeps its state while another is shown.
///
/// A document opens in View, the first mode.

abstract class _$ShellMode extends $Notifier<FermanMode> {
  FermanMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FermanMode, FermanMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FermanMode, FermanMode>,
              FermanMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the user keeps the sidebar open, as `shellSidebarOpenProvider`
/// (FmWindow `sidebar`, open by default). A narrow window can still leave
/// it out ([ShellPanels]).

@ProviderFor(ShellSidebarOpen)
final shellSidebarOpenProvider = ShellSidebarOpenProvider._();

/// Whether the user keeps the sidebar open, as `shellSidebarOpenProvider`
/// (FmWindow `sidebar`, open by default). A narrow window can still leave
/// it out ([ShellPanels]).
final class ShellSidebarOpenProvider
    extends $NotifierProvider<ShellSidebarOpen, bool> {
  /// Whether the user keeps the sidebar open, as `shellSidebarOpenProvider`
  /// (FmWindow `sidebar`, open by default). A narrow window can still leave
  /// it out ([ShellPanels]).
  ShellSidebarOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellSidebarOpenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellSidebarOpenHash();

  @$internal
  @override
  ShellSidebarOpen create() => ShellSidebarOpen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$shellSidebarOpenHash() => r'80c1d6fba3764c89afc8e09f3979a8d6d6c2c5f9';

/// Whether the user keeps the sidebar open, as `shellSidebarOpenProvider`
/// (FmWindow `sidebar`, open by default). A narrow window can still leave
/// it out ([ShellPanels]).

abstract class _$ShellSidebarOpen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the user keeps the right panel open, as `shellPanelOpenProvider`
/// (FmWindow `panel`, open by default). A narrow window can still leave it
/// out ([ShellPanels]).

@ProviderFor(ShellPanelOpen)
final shellPanelOpenProvider = ShellPanelOpenProvider._();

/// Whether the user keeps the right panel open, as `shellPanelOpenProvider`
/// (FmWindow `panel`, open by default). A narrow window can still leave it
/// out ([ShellPanels]).
final class ShellPanelOpenProvider
    extends $NotifierProvider<ShellPanelOpen, bool> {
  /// Whether the user keeps the right panel open, as `shellPanelOpenProvider`
  /// (FmWindow `panel`, open by default). A narrow window can still leave it
  /// out ([ShellPanels]).
  ShellPanelOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellPanelOpenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellPanelOpenHash();

  @$internal
  @override
  ShellPanelOpen create() => ShellPanelOpen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$shellPanelOpenHash() => r'25c08706b6b3d3afe0cc287fce3777c5b62e0823';

/// Whether the user keeps the right panel open, as `shellPanelOpenProvider`
/// (FmWindow `panel`, open by default). A narrow window can still leave it
/// out ([ShellPanels]).

abstract class _$ShellPanelOpen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The side panel the user opened last, as `shellPanelPreferenceProvider`:
/// when the window has room for only one of the open panels, this one
/// stays (G21). The sidebar at first, so the right panel steps aside
/// first.

@ProviderFor(ShellPanelPreference)
final shellPanelPreferenceProvider = ShellPanelPreferenceProvider._();

/// The side panel the user opened last, as `shellPanelPreferenceProvider`:
/// when the window has room for only one of the open panels, this one
/// stays (G21). The sidebar at first, so the right panel steps aside
/// first.
final class ShellPanelPreferenceProvider
    extends $NotifierProvider<ShellPanelPreference, ShellSide> {
  /// The side panel the user opened last, as `shellPanelPreferenceProvider`:
  /// when the window has room for only one of the open panels, this one
  /// stays (G21). The sidebar at first, so the right panel steps aside
  /// first.
  ShellPanelPreferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellPanelPreferenceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellPanelPreferenceHash();

  @$internal
  @override
  ShellPanelPreference create() => ShellPanelPreference();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellSide value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellSide>(value),
    );
  }
}

String _$shellPanelPreferenceHash() =>
    r'3becb59bd2cb26ec96734d9b834339218d54437b';

/// The side panel the user opened last, as `shellPanelPreferenceProvider`:
/// when the window has room for only one of the open panels, this one
/// stays (G21). The sidebar at first, so the right panel steps aside
/// first.

abstract class _$ShellPanelPreference extends $Notifier<ShellSide> {
  ShellSide build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ShellSide, ShellSide>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShellSide, ShellSide>,
              ShellSide,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The width the shell was last laid out at, as `shellWidthProvider`, or
/// null before its first layout. `FmWindow` measures it after each
/// layout; the panel toggles and their shortcuts read [shellPanelsProvider]
/// from it. Kept alive, so it outlasts the frames nobody watches it.

@ProviderFor(ShellWidth)
final shellWidthProvider = ShellWidthProvider._();

/// The width the shell was last laid out at, as `shellWidthProvider`, or
/// null before its first layout. `FmWindow` measures it after each
/// layout; the panel toggles and their shortcuts read [shellPanelsProvider]
/// from it. Kept alive, so it outlasts the frames nobody watches it.
final class ShellWidthProvider extends $NotifierProvider<ShellWidth, double?> {
  /// The width the shell was last laid out at, as `shellWidthProvider`, or
  /// null before its first layout. `FmWindow` measures it after each
  /// layout; the panel toggles and their shortcuts read [shellPanelsProvider]
  /// from it. Kept alive, so it outlasts the frames nobody watches it.
  ShellWidthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellWidthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellWidthHash();

  @$internal
  @override
  ShellWidth create() => ShellWidth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }
}

String _$shellWidthHash() => r'9f6430a54143fa0af650620fc5106ff42ed09068';

/// The width the shell was last laid out at, as `shellWidthProvider`, or
/// null before its first layout. `FmWindow` measures it after each
/// layout; the panel toggles and their shortcuts read [shellPanelsProvider]
/// from it. Kept alive, so it outlasts the frames nobody watches it.

abstract class _$ShellWidth extends $Notifier<double?> {
  double? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double?, double?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double?, double?>,
              double?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The side panels shown at the shell's last measured width, as
/// `shellPanelsProvider` ([ShellPanels.resolve]).

@ProviderFor(shellPanels)
final shellPanelsProvider = ShellPanelsProvider._();

/// The side panels shown at the shell's last measured width, as
/// `shellPanelsProvider` ([ShellPanels.resolve]).

final class ShellPanelsProvider
    extends $FunctionalProvider<ShellPanels, ShellPanels, ShellPanels>
    with $Provider<ShellPanels> {
  /// The side panels shown at the shell's last measured width, as
  /// `shellPanelsProvider` ([ShellPanels.resolve]).
  ShellPanelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellPanelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellPanelsHash();

  @$internal
  @override
  $ProviderElement<ShellPanels> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellPanels create(Ref ref) {
    return shellPanels(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellPanels value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellPanels>(value),
    );
  }
}

String _$shellPanelsHash() => r'dd8ff9f27b56ef8898e40cc1731fc1cb412528fd';

/// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
/// state, not routes, shown over an `IndexedStack` (ADR 0011).
///
/// Kept alive: the sidebar leaves the tree while it is hidden, and the tab
/// chosen before must still show when it comes back.

@ProviderFor(ShellSidebarTab)
final shellSidebarTabProvider = ShellSidebarTabProvider._();

/// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
/// state, not routes, shown over an `IndexedStack` (ADR 0011).
///
/// Kept alive: the sidebar leaves the tree while it is hidden, and the tab
/// chosen before must still show when it comes back.
final class ShellSidebarTabProvider
    extends $NotifierProvider<ShellSidebarTab, SidebarTab> {
  /// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
  /// state, not routes, shown over an `IndexedStack` (ADR 0011).
  ///
  /// Kept alive: the sidebar leaves the tree while it is hidden, and the tab
  /// chosen before must still show when it comes back.
  ShellSidebarTabProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellSidebarTabProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellSidebarTabHash();

  @$internal
  @override
  ShellSidebarTab create() => ShellSidebarTab();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SidebarTab value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SidebarTab>(value),
    );
  }
}

String _$shellSidebarTabHash() => r'8913200950bbc3126c4aedec4c0b149132fe1d15';

/// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
/// state, not routes, shown over an `IndexedStack` (ADR 0011).
///
/// Kept alive: the sidebar leaves the tree while it is hidden, and the tab
/// chosen before must still show when it comes back.

abstract class _$ShellSidebarTab extends $Notifier<SidebarTab> {
  SidebarTab build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SidebarTab, SidebarTab>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SidebarTab, SidebarTab>,
              SidebarTab,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the AI assistant is turned on, as `shellAiEnabledProvider`. The
/// mode bar shows its button only when it is on (FmWindow `aiOn`). Off in
/// M1: the assistant comes in phase 4 and is off by default even then.

@ProviderFor(shellAiEnabled)
final shellAiEnabledProvider = ShellAiEnabledProvider._();

/// Whether the AI assistant is turned on, as `shellAiEnabledProvider`. The
/// mode bar shows its button only when it is on (FmWindow `aiOn`). Off in
/// M1: the assistant comes in phase 4 and is off by default even then.

final class ShellAiEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the AI assistant is turned on, as `shellAiEnabledProvider`. The
  /// mode bar shows its button only when it is on (FmWindow `aiOn`). Off in
  /// M1: the assistant comes in phase 4 and is off by default even then.
  ShellAiEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellAiEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellAiEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return shellAiEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$shellAiEnabledHash() => r'4a31c7fc5fea6c67f8687c02c5091743ec250e88';

/// The key conventions the shell shows and binds, as
/// `shortcutPlatformProvider`: the system the app runs on. Tests override
/// it to check another system.

@ProviderFor(shortcutPlatform)
final shortcutPlatformProvider = ShortcutPlatformProvider._();

/// The key conventions the shell shows and binds, as
/// `shortcutPlatformProvider`: the system the app runs on. Tests override
/// it to check another system.

final class ShortcutPlatformProvider
    extends
        $FunctionalProvider<
          ShortcutPlatform,
          ShortcutPlatform,
          ShortcutPlatform
        >
    with $Provider<ShortcutPlatform> {
  /// The key conventions the shell shows and binds, as
  /// `shortcutPlatformProvider`: the system the app runs on. Tests override
  /// it to check another system.
  ShortcutPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shortcutPlatformProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shortcutPlatformHash();

  @$internal
  @override
  $ProviderElement<ShortcutPlatform> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShortcutPlatform create(Ref ref) {
    return shortcutPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShortcutPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShortcutPlatform>(value),
    );
  }
}

String _$shortcutPlatformHash() => r'e178a9005d056a5b6519dbf4826a74a3d7cef5b2';

/// The open documents, as `shellDocumentsProvider`.
///
/// Until the first document opens these are the M1 placeholder documents
/// that show every tab state the design draws (DS additions `tabStates`,
/// a1-10): the active clean contract, an idle clean invoice, an idle
/// statement with unsaved changes, a report still opening, a locked
/// payslip, and three more behind "+3". The names are the design's sample
/// files, not copy. The first document opened ([add]) replaces them.
// shortcut: the placeholders stay the starting state for the M1 shell
// tests and `/debug/shell`; drop them with the debug route (end of M2).

@ProviderFor(ShellDocuments)
final shellDocumentsProvider = ShellDocumentsProvider._();

/// The open documents, as `shellDocumentsProvider`.
///
/// Until the first document opens these are the M1 placeholder documents
/// that show every tab state the design draws (DS additions `tabStates`,
/// a1-10): the active clean contract, an idle clean invoice, an idle
/// statement with unsaved changes, a report still opening, a locked
/// payslip, and three more behind "+3". The names are the design's sample
/// files, not copy. The first document opened ([add]) replaces them.
// shortcut: the placeholders stay the starting state for the M1 shell
// tests and `/debug/shell`; drop them with the debug route (end of M2).
final class ShellDocumentsProvider
    extends $NotifierProvider<ShellDocuments, ShellDocumentList> {
  /// The open documents, as `shellDocumentsProvider`.
  ///
  /// Until the first document opens these are the M1 placeholder documents
  /// that show every tab state the design draws (DS additions `tabStates`,
  /// a1-10): the active clean contract, an idle clean invoice, an idle
  /// statement with unsaved changes, a report still opening, a locked
  /// payslip, and three more behind "+3". The names are the design's sample
  /// files, not copy. The first document opened ([add]) replaces them.
  // shortcut: the placeholders stay the starting state for the M1 shell
  // tests and `/debug/shell`; drop them with the debug route (end of M2).
  ShellDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellDocumentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellDocumentsHash();

  @$internal
  @override
  ShellDocuments create() => ShellDocuments();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellDocumentList value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellDocumentList>(value),
    );
  }
}

String _$shellDocumentsHash() => r'ba3672a8d8be892bd17407f54ebf7c152ea69b10';

/// The open documents, as `shellDocumentsProvider`.
///
/// Until the first document opens these are the M1 placeholder documents
/// that show every tab state the design draws (DS additions `tabStates`,
/// a1-10): the active clean contract, an idle clean invoice, an idle
/// statement with unsaved changes, a report still opening, a locked
/// payslip, and three more behind "+3". The names are the design's sample
/// files, not copy. The first document opened ([add]) replaces them.
// shortcut: the placeholders stay the starting state for the M1 shell
// tests and `/debug/shell`; drop them with the debug route (end of M2).

abstract class _$ShellDocuments extends $Notifier<ShellDocumentList> {
  ShellDocumentList build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ShellDocumentList, ShellDocumentList>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShellDocumentList, ShellDocumentList>,
              ShellDocumentList,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
