import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/foundation.dart';
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

/// Whether the sidebar is shown, as `shellSidebarOpenProvider` (FmWindow
/// `sidebar`, open by default).
@riverpod
class ShellSidebarOpen extends _$ShellSidebarOpen {
  @override
  bool build() => true;

  /// Shows the sidebar when it is hidden and hides it when it is shown.
  void toggle() => state = !state;
}

/// Whether the right panel is shown, as `shellPanelOpenProvider` (FmWindow
/// `panel`, open by default).
@riverpod
class ShellPanelOpen extends _$ShellPanelOpen {
  @override
  bool build() => true;

  /// Shows the panel when it is hidden and hides it when it is shown.
  void toggle() => state = !state;
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

/// An open document as the M1 shell shows it: placeholder data, since
/// documents open from M2 on. The title bar's tab, the Save button and the
/// status bar all read the same document, so they always agree (fix 4).
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
  });

  /// The file name.
  final String name;

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

  /// The document shown, or null when none is open.
  ShellDocument? get active =>
      activeIndex >= 0 && activeIndex < documents.length
      ? documents[activeIndex]
      : null;
}

/// The open documents, as `shellDocumentsProvider`.
///
/// In M1 these are placeholder documents that show every tab state the
/// design draws (DS additions `tabStates`, a1-10): the active clean
/// contract, an idle clean invoice, an idle statement with unsaved changes,
/// a report still opening, a locked payslip, and three more behind "+3".
/// The names are the design's sample files, not copy. Activating a tab
/// shows that document's save state, pages and edits in the shell; nothing
/// is rendered until M2.
@riverpod
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

  /// Shows the document after the active one, wrapping to the first.
  void activateNext() {
    final count = state.documents.length;
    if (count == 0) return;
    activate((state.activeIndex + 1) % count);
  }
}
