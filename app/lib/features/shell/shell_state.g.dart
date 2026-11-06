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

String _$shellModeHash() => r'15bf3360ef849118b1082b7489e629dc78176da2';

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

/// The widths the user dragged the sidebar and the right panel to (B094),
/// as `shellPaneWidthsProvider`. Each starts at its FmWindow width, which
/// is also its narrowest ([minWidth]); [maxWidth] is the widest. No board
/// draws the limits (G21). Not stored: a new window starts at the
/// designed widths.

@ProviderFor(ShellPaneWidths)
final shellPaneWidthsProvider = ShellPaneWidthsProvider._();

/// The widths the user dragged the sidebar and the right panel to (B094),
/// as `shellPaneWidthsProvider`. Each starts at its FmWindow width, which
/// is also its narrowest ([minWidth]); [maxWidth] is the widest. No board
/// draws the limits (G21). Not stored: a new window starts at the
/// designed widths.
final class ShellPaneWidthsProvider
    extends
        $NotifierProvider<ShellPaneWidths, ({double panel, double sidebar})> {
  /// The widths the user dragged the sidebar and the right panel to (B094),
  /// as `shellPaneWidthsProvider`. Each starts at its FmWindow width, which
  /// is also its narrowest ([minWidth]); [maxWidth] is the widest. No board
  /// draws the limits (G21). Not stored: a new window starts at the
  /// designed widths.
  ShellPaneWidthsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellPaneWidthsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellPaneWidthsHash();

  @$internal
  @override
  ShellPaneWidths create() => ShellPaneWidths();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({double panel, double sidebar}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({double panel, double sidebar})>(
        value,
      ),
    );
  }
}

String _$shellPaneWidthsHash() => r'bcbb4ae6d6a367b133341937fa9c74919aab10fe';

/// The widths the user dragged the sidebar and the right panel to (B094),
/// as `shellPaneWidthsProvider`. Each starts at its FmWindow width, which
/// is also its narrowest ([minWidth]); [maxWidth] is the widest. No board
/// draws the limits (G21). Not stored: a new window starts at the
/// designed widths.

abstract class _$ShellPaneWidths
    extends $Notifier<({double panel, double sidebar})> {
  ({double panel, double sidebar}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({double panel, double sidebar}),
              ({double panel, double sidebar})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({double panel, double sidebar}),
                ({double panel, double sidebar})
              >,
              ({double panel, double sidebar}),
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
/// Each document keeps its own tab in `documentMemoryProvider`, so
/// switching tabs, hiding the sidebar or going home brings it back; a new
/// document starts on Pages.

@ProviderFor(ShellSidebarTab)
final shellSidebarTabProvider = ShellSidebarTabProvider._();

/// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
/// state, not routes, shown over an `IndexedStack` (ADR 0011).
///
/// Each document keeps its own tab in `documentMemoryProvider`, so
/// switching tabs, hiding the sidebar or going home brings it back; a new
/// document starts on Pages.
final class ShellSidebarTabProvider
    extends $NotifierProvider<ShellSidebarTab, SidebarTab> {
  /// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
  /// state, not routes, shown over an `IndexedStack` (ADR 0011).
  ///
  /// Each document keeps its own tab in `documentMemoryProvider`, so
  /// switching tabs, hiding the sidebar or going home brings it back; a new
  /// document starts on Pages.
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

String _$shellSidebarTabHash() => r'4b9471a716c5043c394be559b65eb1ef0ffbf22d';

/// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
/// state, not routes, shown over an `IndexedStack` (ADR 0011).
///
/// Each document keeps its own tab in `documentMemoryProvider`, so
/// switching tabs, hiding the sidebar or going home brings it back; a new
/// document starts on Pages.

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

/// Asks "+N" to list every open document (`⇧⌘\` or `Ctrl+Shift+\`, a1-10's
/// "Show all open documents"): the count of requests, as
/// `showAllDocumentsRequestProvider`. Kept alive: the command holds its
/// notifier while "+N", the only listener, comes and goes with the overflow.

@ProviderFor(ShowAllDocumentsRequest)
final showAllDocumentsRequestProvider = ShowAllDocumentsRequestProvider._();

/// Asks "+N" to list every open document (`⇧⌘\` or `Ctrl+Shift+\`, a1-10's
/// "Show all open documents"): the count of requests, as
/// `showAllDocumentsRequestProvider`. Kept alive: the command holds its
/// notifier while "+N", the only listener, comes and goes with the overflow.
final class ShowAllDocumentsRequestProvider
    extends $NotifierProvider<ShowAllDocumentsRequest, int> {
  /// Asks "+N" to list every open document (`⇧⌘\` or `Ctrl+Shift+\`, a1-10's
  /// "Show all open documents"): the count of requests, as
  /// `showAllDocumentsRequestProvider`. Kept alive: the command holds its
  /// notifier while "+N", the only listener, comes and goes with the overflow.
  ShowAllDocumentsRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showAllDocumentsRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showAllDocumentsRequestHash();

  @$internal
  @override
  ShowAllDocumentsRequest create() => ShowAllDocumentsRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$showAllDocumentsRequestHash() =>
    r'a90415363c05d9102fa283a49d3a7ecd785fb10b';

/// Asks "+N" to list every open document (`⇧⌘\` or `Ctrl+Shift+\`, a1-10's
/// "Show all open documents"): the count of requests, as
/// `showAllDocumentsRequestProvider`. Kept alive: the command holds its
/// notifier while "+N", the only listener, comes and goes with the overflow.

abstract class _$ShowAllDocumentsRequest extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A request to show the active document's properties (a2-7), as
/// `documentPropertiesRequestProvider`: ⌘D bumps it and the canvas shows
/// the dialog. Kept alive for the same reason as [ShowAllDocumentsRequest].

@ProviderFor(DocumentPropertiesRequest)
final documentPropertiesRequestProvider = DocumentPropertiesRequestProvider._();

/// A request to show the active document's properties (a2-7), as
/// `documentPropertiesRequestProvider`: ⌘D bumps it and the canvas shows
/// the dialog. Kept alive for the same reason as [ShowAllDocumentsRequest].
final class DocumentPropertiesRequestProvider
    extends $NotifierProvider<DocumentPropertiesRequest, int> {
  /// A request to show the active document's properties (a2-7), as
  /// `documentPropertiesRequestProvider`: ⌘D bumps it and the canvas shows
  /// the dialog. Kept alive for the same reason as [ShowAllDocumentsRequest].
  DocumentPropertiesRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentPropertiesRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentPropertiesRequestHash();

  @$internal
  @override
  DocumentPropertiesRequest create() => DocumentPropertiesRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$documentPropertiesRequestHash() =>
    r'bbf45ca087ceb6feca0e0e9bbc8ace2b9198fa21';

/// A request to show the active document's properties (a2-7), as
/// `documentPropertiesRequestProvider`: ⌘D bumps it and the canvas shows
/// the dialog. Kept alive for the same reason as [ShowAllDocumentsRequest].

abstract class _$DocumentPropertiesRequest extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
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

/// The open documents, as `shellDocumentsProvider`: none until the first
/// one opens.

@ProviderFor(ShellDocuments)
final shellDocumentsProvider = ShellDocumentsProvider._();

/// The open documents, as `shellDocumentsProvider`: none until the first
/// one opens.
final class ShellDocumentsProvider
    extends $NotifierProvider<ShellDocuments, ShellDocumentList> {
  /// The open documents, as `shellDocumentsProvider`: none until the first
  /// one opens.
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

String _$shellDocumentsHash() => r'b9631551a5856eed4be5a4494b9d7b1e66b47013';

/// The open documents, as `shellDocumentsProvider`: none until the first
/// one opens.

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
