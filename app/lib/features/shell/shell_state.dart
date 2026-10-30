import 'dart:math' as math;

import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_state.g.dart';

/// The mode shown, as `shellModeProvider`. Modes are state, not routes
/// (ADR 0011); the shell shows each mode's tool row in an `IndexedStack`,
/// so a mode keeps its state while another is shown.
///
/// A document opens in View, the first mode.
@riverpod
class ShellMode extends _$ShellMode {
  @override
  FermanMode build() => FermanMode.view;

  /// Shows [mode]; nothing happens when it is already shown.
  void select(FermanMode mode) {
    if (mode == state) return;
    state = mode;
  }
}

/// Whether the user keeps the sidebar open, as `shellSidebarOpenProvider`
/// (FmWindow `sidebar`, open by default). A narrow window can still leave
/// it out ([ShellPanels]).
@riverpod
class ShellSidebarOpen extends _$ShellSidebarOpen {
  @override
  bool build() => true;

  /// Opens the sidebar when it is closed and closes it when it is open.
  void toggle() => state = !state;

  /// Opens the sidebar.
  void open() => state = true;

  /// Closes the sidebar.
  void close() => state = false;
}

/// Whether the user keeps the right panel open, as `shellPanelOpenProvider`
/// (FmWindow `panel`, open by default). A narrow window can still leave it
/// out ([ShellPanels]).
@riverpod
class ShellPanelOpen extends _$ShellPanelOpen {
  @override
  bool build() => true;

  /// Opens the panel when it is closed and closes it when it is open.
  void toggle() => state = !state;

  /// Opens the panel.
  void open() => state = true;

  /// Closes the panel.
  void close() => state = false;
}

/// The two side panels of the shell.
enum ShellSide {
  /// The sidebar, on the start side.
  sidebar,

  /// The right panel, on the end side.
  panel,
}

/// The side panel the user opened last, as `shellPanelPreferenceProvider`:
/// when the window has room for only one of the open panels, this one
/// stays (G21). The sidebar at first, so the right panel steps aside
/// first.
@riverpod
class ShellPanelPreference extends _$ShellPanelPreference {
  @override
  ShellSide build() => ShellSide.sidebar;

  /// Keeps [side] when there is room for only one panel.
  void prefer(ShellSide side) {
    if (side == state) return;
    state = side;
  }
}

/// The width the shell was last laid out at, as `shellWidthProvider`, or
/// null before its first layout. `FmWindow` measures it after each
/// layout; the panel toggles and their shortcuts read [shellPanelsProvider]
/// from it. Kept alive, so it outlasts the frames nobody watches it.
@Riverpod(keepAlive: true)
class ShellWidth extends _$ShellWidth {
  @override
  double? build() => null;

  /// Records the measured [width].
  void measured(double width) {
    if (width == state) return;
    state = width;
  }
}

/// Which side panels the shell shows: the ones the user keeps open, as long
/// as the canvas keeps [WindowMetrics.canvasMinWidth] beside them (G21).
///
/// Panels collapse before anything overlaps. When both are open and only
/// one fits, the one the user opened last stays and the other steps aside
/// (the right panel first by default: the document is the hero); when
/// even that one does not fit, the other is tried; at the narrowest none
/// shows. A panel that steps aside stays open: it comes back as soon as
/// there is room, when the window widens or the other panel closes.
///
/// A panel that does not fit even on its own (the right panel below 904 px,
/// the sidebar below 856: the web and narrow tablets, below the desktop
/// minimum) is unavailable: its toggle and shortcut are disabled with the
/// reason, and its open state waits for a wider window.
@immutable
final class ShellPanels {
  /// The sidebar shown or not, and the right panel, and whether each could
  /// show on its own.
  const new({
    required this.sidebar,
    required this.panel,
    this.sidebarAvailable = true,
    this.panelAvailable = true,
  });

  /// The panels shown in a shell [width] wide (null: not laid out yet,
  /// every open panel shows) with the sidebar and the panel open or not
  /// and [preferred] kept first.
  factory resolve({
    required double? width,
    required bool sidebarOpen,
    required bool panelOpen,
    required ShellSide preferred,
  }) {
    if (width == null) {
      return ShellPanels(sidebar: sidebarOpen, panel: panelOpen);
    }
    const canvas = WindowMetrics.canvasMinWidth;
    double widthOf(ShellSide side) => switch (side) {
      ShellSide.sidebar => FermanSizeTokens.sidebarW,
      ShellSide.panel => FermanSizeTokens.panelW,
    };
    bool fits(Iterable<ShellSide> sides) =>
        sides.fold(canvas, (sum, side) => sum + widthOf(side)) <= width;
    final open = [
      if (sidebarOpen) ShellSide.sidebar,
      if (panelOpen) ShellSide.panel,
    ];
    var shown = <ShellSide>[];
    if (fits(open)) {
      shown = open;
    } else {
      // The preferred panel first, then the other; one at most.
      final order = [...open]
        ..sort((a, b) => (a == preferred ? 0 : 1) - (b == preferred ? 0 : 1));
      for (final side in order) {
        if (fits([side])) {
          shown = [side];
          break;
        }
      }
    }
    return ShellPanels(
      sidebar: shown.contains(ShellSide.sidebar),
      panel: shown.contains(ShellSide.panel),
      sidebarAvailable: fits([ShellSide.sidebar]),
      panelAvailable: fits([ShellSide.panel]),
    );
  }

  /// Whether the sidebar shows.
  final bool sidebar;

  /// Whether the right panel shows.
  final bool panel;

  /// Whether the sidebar fits beside the canvas on its own.
  final bool sidebarAvailable;

  /// Whether the right panel fits beside the canvas on its own.
  final bool panelAvailable;

  /// Whether [side] fits beside the canvas on its own: its toggle works.
  bool available(ShellSide side) => switch (side) {
    ShellSide.sidebar => sidebarAvailable,
    ShellSide.panel => panelAvailable,
  };

  /// Whether [side] shows.
  bool shows(ShellSide side) => switch (side) {
    ShellSide.sidebar => sidebar,
    ShellSide.panel => panel,
  };

  @override
  bool operator ==(Object other) =>
      other is ShellPanels &&
      other.sidebar == sidebar &&
      other.panel == panel &&
      other.sidebarAvailable == sidebarAvailable &&
      other.panelAvailable == panelAvailable;

  @override
  int get hashCode =>
      Object.hash(sidebar, panel, sidebarAvailable, panelAvailable);

  @override
  String toString() =>
      'ShellPanels(sidebar: $sidebar, panel: $panel, '
      'available: $sidebarAvailable, $panelAvailable)';
}

/// The side panels the shell shows at the width it is laid out at, for the
/// mode bar's toggles, which show and switch them ([toggleShellSide]).
class ShellPanelsScope extends InheritedWidget {
  /// Gives [panels] to [child].
  const new({required this.panels, required super.child, super.key});

  /// The panels shown.
  final ShellPanels panels;

  /// The panels the shell around [context] shows, or null outside one.
  static ShellPanels? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellPanelsScope>()?.panels;

  @override
  bool updateShouldNotify(ShellPanelsScope oldWidget) =>
      panels != oldWidget.panels;
}

/// The side panels shown at the shell's last measured width, as
/// `shellPanelsProvider` ([ShellPanels.resolve]).
@riverpod
ShellPanels shellPanels(Ref ref) => ShellPanels.resolve(
  width: ref.watch(shellWidthProvider),
  sidebarOpen: ref.watch(shellSidebarOpenProvider),
  panelOpen: ref.watch(shellPanelOpenProvider),
  preferred: ref.watch(shellPanelPreferenceProvider),
);

/// What the sidebar and panel toggles and their shortcuts do (G21): a
/// panel that shows closes; one that does not (closed, or stepped aside in
/// a narrow window) opens and becomes the one kept, so the other steps
/// aside when there is room for only one. A panel that does not fit even
/// on its own is left as it is ([ShellPanels.available]; its toggle is
/// disabled). [shown] is what the shell shows now; null reads
/// [shellPanelsProvider].
void toggleShellSide(WidgetRef ref, ShellSide side, {ShellPanels? shown}) {
  // The type argument keeps `??` from asking for a nullable value.
  final panels = shown ?? ref.read<ShellPanels>(shellPanelsProvider);
  if (!panels.available(side)) return;
  final opens = !panels.shows(side);
  switch ((side, opens)) {
    case (ShellSide.sidebar, true):
      ref.read(shellSidebarOpenProvider.notifier).open();
    case (ShellSide.sidebar, false):
      ref.read(shellSidebarOpenProvider.notifier).close();
    case (ShellSide.panel, true):
      ref.read(shellPanelOpenProvider.notifier).open();
    case (ShellSide.panel, false):
      ref.read(shellPanelOpenProvider.notifier).close();
  }
  if (opens) ref.read(shellPanelPreferenceProvider.notifier).prefer(side);
}

/// The tabs of the sidebar, in the drawn order (FmSidebar `tabOptions`).
enum SidebarTab {
  /// Page thumbnails (`files`).
  pages(IconName.files),

  /// The outline, the document's bookmarks (`list-tree`).
  outline(IconName.listTree),

  /// Embedded files (`paperclip`).
  attachments(IconName.paperclip),

  /// Optional content layers (`layers`).
  layers(IconName.layers),

  /// Signatures and signature fields (`signature`).
  signatures(IconName.signature),

  /// Search results (`search`).
  search(IconName.search);

  new(this.icon);

  /// The glyph of the tab's segment.
  final IconName icon;
}

/// The sidebar tab shown, as `shellSidebarTabProvider`. Sidebar tabs are
/// state, not routes, shown over an `IndexedStack` (ADR 0011).
///
/// Kept alive: the sidebar leaves the tree while it is hidden, and the tab
/// chosen before must still show when it comes back.
@Riverpod(keepAlive: true)
class ShellSidebarTab extends _$ShellSidebarTab {
  @override
  SidebarTab build() => SidebarTab.pages;

  /// Shows [tab]; nothing happens when it is already shown.
  void select(SidebarTab tab) {
    if (tab == state) return;
    state = tab;
  }
}

/// Whether the AI assistant is turned on, as `shellAiEnabledProvider`. The
/// mode bar shows its button only when it is on (FmWindow `aiOn`). Off in
/// M1: the assistant comes in phase 4 and is off by default even then.
@riverpod
bool shellAiEnabled(Ref ref) => false;

/// The key conventions the shell shows and binds, as
/// `shortcutPlatformProvider`: the system the app runs on. Tests override
/// it to check another system.
@riverpod
ShortcutPlatform shortcutPlatform(Ref ref) => ShortcutPlatform.current;

/// An open document as the shell shows it: the title bar's tab, the Save
/// button and the status bar all read the same document, so they always
/// agree (fix 4). A document the engine opened has its [path] and
/// [document]; the M1 placeholders have neither.
@immutable
final class ShellDocument {
  /// A document named [name].
  const new({
    required this.name,
    this.icon = IconName.fileText,
    this.saveState,
    this.savedAt,
    this.pageCount,
    this.editCount = 0,
    this.path,
    this.document,
  });

  /// The file name.
  final String name;

  /// Where the file is.
  final String? path;

  /// The engine's document, which the canvas shows.
  final OpenedDocument? document;

  /// The tab's glyph: `file-text`, or `lock` for a locked file.
  final IconName icon;

  /// The save state, or null while the document is still opening.
  final SaveState? saveState;

  /// When the document was last saved on this device.
  final DateTime? savedAt;

  /// The number of pages, or null while it is unknown (opening, locked).
  final int? pageCount;

  /// The edits made in this session (the Review edits badge).
  final int editCount;

  /// Whether the document is still opening.
  bool get loading => saveState == null;

  /// Whether the document has unsaved changes.
  bool get unsaved => saveState == SaveState.unsaved;
}

/// The open documents and which one is shown.
@immutable
final class ShellDocumentList {
  /// [documents] with the one at [activeIndex] shown and [overflowCount]
  /// more that do not fit in the title bar.
  const new({
    required this.documents,
    this.activeIndex = 0,
    this.overflowCount = 0,
  });

  /// The documents shown as tabs, in order.
  final List<ShellDocument> documents;

  /// The index of the document shown below the title bar.
  final int activeIndex;

  /// How many more documents are open than the tabs show (the "+N"
  /// button).
  final int overflowCount;

  /// Whether these are the M1 placeholders (no document opened yet).
  bool get placeholder => identical(documents, ShellDocuments.placeholders);

  /// The indexes of the documents whose tabs show when only [fit] tabs fit,
  /// in order: the first ones, with the active one in the last place when
  /// it lies further on (a1-10); the rest go behind "+N".
  List<int> shown(int fit) {
    final count = documents.length;
    if (count <= fit || count == 0) {
      return [for (var i = 0; i < count; i++) i];
    }
    final last = math.max(fit, 1) - 1;
    return [for (var i = 0; i < last; i++) i, math.max(activeIndex, last)];
  }

  /// The document shown, or null when none is open.
  ShellDocument? get active =>
      activeIndex >= 0 && activeIndex < documents.length
      ? documents[activeIndex]
      : null;
}

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
@Riverpod(keepAlive: true)
class ShellDocuments extends _$ShellDocuments {
  /// The placeholder documents.
  static final List<ShellDocument> placeholders = [
    ShellDocument(
      name: 'Kira sözleşmesi.pdf',
      saveState: SaveState.saved,
      savedAt: DateTime(2026, 10, 13, 14, 32),
      pageCount: 3,
    ),
    ShellDocument(
      name: 'e-Arşiv fatura 4187.pdf',
      saveState: SaveState.saved,
      savedAt: DateTime(2026, 10, 13, 11, 5),
      pageCount: 1,
    ),
    const ShellDocument(
      name: 'Hesap ekstresi Eylül 2026.pdf',
      saveState: SaveState.unsaved,
      pageCount: 2,
      editCount: 3,
    ),
    const ShellDocument(name: 'İmar planı açıklama raporu.pdf'),
    const ShellDocument(
      name: 'Maaş bordrosu Eylül 2026.pdf',
      icon: IconName.lock,
      saveState: SaveState.readOnly,
    ),
  ];

  @override
  ShellDocumentList build() =>
      ShellDocumentList(documents: placeholders, overflowCount: 3);

  /// Shows the document at [index].
  void activate(int index) {
    if (index < 0 || index >= state.documents.length) return;
    state = ShellDocumentList(
      documents: state.documents,
      activeIndex: index,
      overflowCount: state.overflowCount,
    );
  }

  /// Adds [document] as the last tab and shows it; the first one replaces
  /// the placeholders.
  void add(ShellDocument document) {
    final documents = state.placeholder
        ? const <ShellDocument>[]
        : state.documents;
    state = ShellDocumentList(
      documents: [...documents, document],
      activeIndex: documents.length,
    );
  }

  /// Shows the document opened from [path], if one is; whether one was.
  bool focus(String path) {
    final index = state.documents.indexWhere(
      (document) => document.path == path,
    );
    activate(index);
    return index >= 0;
  }

  /// Shows the document after the active one, wrapping to the first.
  void activateNext() {
    final count = state.documents.length;
    if (count == 0) return;
    activate((state.activeIndex + 1) % count);
  }
}
