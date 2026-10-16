import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The key conventions of a system: macOS writes ⌘ ⌥ ⇧ ⌃, Windows and
/// Linux write Ctrl, Alt and Shift and use Ctrl where macOS uses ⌘ (G15,
/// f6, f6a).
enum ShortcutPlatform {
  /// macOS (and iPadOS with a hardware keyboard).
  mac,

  /// Windows.
  windows,

  /// Linux, and Android with a hardware keyboard (a14-1d): the Windows
  /// conventions, with a few window commands of its own.
  linux;

  /// The conventions of [platform].
  static ShortcutPlatform of(TargetPlatform platform) => switch (platform) {
    TargetPlatform.macOS || TargetPlatform.iOS => mac,
    TargetPlatform.windows => windows,
    TargetPlatform.linux ||
    TargetPlatform.android ||
    TargetPlatform.fuchsia => linux,
  };

  /// The conventions of the system the app runs on.
  static ShortcutPlatform get current => of(defaultTargetPlatform);
}

/// Where a shortcut applies.
enum ShortcutScope {
  /// Anywhere in the window: the title bar and the shell below it.
  window,

  /// Only while the document canvas has focus, where Tab moves between form
  /// fields and the arrow keys turn pages instead of moving focus.
  canvas,
}

/// One key combination of the shortcut table.
///
/// The modifiers are the physical keys: [meta] is ⌘ on macOS (the Windows
/// key elsewhere, which the table never uses), [control] is ⌃ on macOS and
/// Ctrl elsewhere. [keyCap] replaces the key's own cap where the design
/// writes another one: `+` for the `=` key that zoom in uses.
@immutable
final class KeyBinding {
  /// [key] with the given modifiers.
  const new(
    this.key, {
    this.meta = false,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.keyCap,
  });

  /// The key.
  final LogicalKeyboardKey key;

  /// ⌘ on macOS.
  final bool meta;

  /// ⌃ on macOS, Ctrl on Windows and Linux.
  final bool control;

  /// ⌥ on macOS, Alt on Windows and Linux.
  final bool alt;

  /// ⇧ on macOS, Shift on Windows and Linux.
  final bool shift;

  /// The cap shown for [key] instead of its own; null uses the key's cap.
  final String? keyCap;

  /// Whether the combination has no ⌘, Ctrl or Alt: a single key such as
  /// `V` or `⇧T`, which must not fire while the user types text.
  bool get isPlain => !meta && !control && !alt;

  /// The activator for [Shortcuts].
  SingleActivator get activator => SingleActivator(
    key,
    meta: meta,
    control: control,
    alt: alt,
    shift: shift,
  );

  /// The same combination written the same way: two bindings with equal
  /// identities collide.
  String get identity =>
      '${control ? 'C' : ''}${alt ? 'A' : ''}${shift ? 'S' : ''}'
      '${meta ? 'M' : ''}+${key.keyId}';

  /// The key caps of this combination on [platform], as `Kbd` and tooltips
  /// show them: `⌥ ⌘ F` on macOS (modifiers in Apple's order ⌃ ⌥ ⇧ ⌘),
  /// `Ctrl Alt S` on Windows and Linux (Ctrl, Alt, Shift).
  List<String> caps(ShortcutPlatform platform) => [
    if (platform == ShortcutPlatform.mac) ...[
      if (control) '⌃',
      if (alt) '⌥',
      if (shift) '⇧',
      if (meta) '⌘',
    ] else ...[
      if (control) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (meta) 'Win',
    ],
    keyCap ?? capOf(key, platform),
  ];

  /// The cap of [key] on [platform]: letters and digits as themselves, the
  /// arrows as arrows, ⌫ for Backspace (FmWindow `k.del`), `−` (U+2212)
  /// for minus, as FmWindow writes zoom out, and Del, Esc, Tab and F4 by
  /// name.
  static String capOf(LogicalKeyboardKey key, ShortcutPlatform platform) {
    final mac = platform == ShortcutPlatform.mac;
    if (key == LogicalKeyboardKey.backspace) return '⌫';
    if (key == LogicalKeyboardKey.delete) return mac ? '⌦' : 'Del';
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      return '−';
    }
    if (key == LogicalKeyboardKey.numpadAdd) return '+';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.enter) return '↵';
    return key.keyLabel;
  }

  @override
  bool operator ==(Object other) =>
      other is KeyBinding && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;

  @override
  String toString() => 'KeyBinding($identity)';
}

typedef _Key = LogicalKeyboardKey;

/// The one shortcut table of the app (M1 phase H5, ADR 0011, G44): every
/// command the shell's controls, FmWindow (`k` in its script), the
/// cheat sheet (a11-3), the zoom menu (a2-2), the tab overflow note
/// (a1-10), the Organize notes (a6) and the hardware-keyboard list
/// (a14-1d) show, with its keys on each system.
///
/// Each command lists its bindings for [mac], [windows] and [linux]; the
/// first is the one tooltips and menus show ([caps]), any others are
/// aliases (numpad keys, Delete beside Backspace). [modes] limits a command
/// to some modes (null: every mode) and [scope] to the canvas.
///
/// Decisions (G44, G81):
///
/// - **⌥⌘S** (G44): Save a copy keeps ⌥⌘S; the sidebar moves to ⌃⌘S on
///   macOS; Add signature gets ⇧S, active only in Fill & Sign. On Windows
///   and Linux the sidebar keeps Ctrl+Alt+S as FmWindow draws it, so Save
///   a copy has no key there.
/// - **⌘1…⌘9** (a1-10, G81) collide with Actual size ⌘1 and Fit width ⌘2
///   (a2-2): zoom keeps them, and the document jump takes ⌥⌘1…⌥⌘9 on
///   macOS and Alt+1…Alt+9 on Windows and Linux.
/// - **Delete pages** (G81): ⌫ on macOS (FmWindow), Del on Windows and
///   Linux (a14-1d), each with the other key as an alias.
///
/// [conflicts] lists every collision; a test keeps it empty on every
/// system. The text-format keys of the edit box (⌘B, ⌘I, ⌘U, FmEditPanel)
/// and dialog accelerators (⌘D "Don't save") belong to those components,
/// not to this table (G82).
enum ShellCommand {
  /// Opens the command palette (FmWindow `k.palette`, the Search button).
  commandPalette(
    mac: [KeyBinding(_Key.keyK, meta: true)],
    windows: [KeyBinding(_Key.keyK, control: true)],
  ),

  /// Opens Settings (FmWindow `k.settings`).
  settings(
    mac: [KeyBinding(_Key.comma, meta: true)],
    windows: [KeyBinding(_Key.comma, control: true)],
  ),

  /// Shows the keyboard cheat sheet (a11-3 note).
  keyboardShortcuts(
    mac: [KeyBinding(_Key.slash, meta: true)],
    windows: [KeyBinding(_Key.slash, control: true)],
  ),

  /// Opens a file (FmWindow `k.open`, the "+" button).
  open(
    mac: [KeyBinding(_Key.keyO, meta: true)],
    windows: [KeyBinding(_Key.keyO, control: true)],
  ),

  /// Creates a PDF (FmStart "Create PDF").
  createPdf(
    mac: [KeyBinding(_Key.keyN, meta: true)],
    windows: [KeyBinding(_Key.keyN, control: true)],
  ),

  /// Saves the document (a11-3, the Save button).
  save(
    mac: [KeyBinding(_Key.keyS, meta: true)],
    windows: [KeyBinding(_Key.keyS, control: true)],
  ),

  /// Saves the document under another name or format (a11-3, a1-11).
  saveAs(
    mac: [KeyBinding(_Key.keyS, meta: true, shift: true)],
    windows: [KeyBinding(_Key.keyS, control: true, shift: true)],
  ),

  /// Saves a copy and keeps the document open (a1-11 note; G44). No key on
  /// Windows and Linux, where Ctrl+Alt+S is the sidebar.
  saveCopy(mac: [KeyBinding(_Key.keyS, meta: true, alt: true)], windows: []),

  /// Prints (FmWindow `k.print`, the Print tool).
  printDocument(
    mac: [KeyBinding(_Key.keyP, meta: true)],
    windows: [KeyBinding(_Key.keyP, control: true)],
  ),

  /// Closes the active document (FmWindow `k.close`, the tab's close
  /// button), or Settings while it shows (a11-1 draws Settings as a window
  /// of its own, which ⌘W closes).
  closeDocument(
    mac: [KeyBinding(_Key.keyW, meta: true)],
    windows: [KeyBinding(_Key.keyW, control: true)],
  ),

  /// Moves to the next open document (a11-3, a1-10).
  nextDocument(
    mac: [KeyBinding(_Key.tab, control: true)],
    windows: [KeyBinding(_Key.tab, control: true)],
  ),

  /// Jumps to the first open document (a1-10; moved off ⌘1, see above).
  document1(
    mac: [KeyBinding(_Key.digit1, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit1, alt: true)],
  ),

  /// Jumps to the second open document.
  document2(
    mac: [KeyBinding(_Key.digit2, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit2, alt: true)],
  ),

  /// Jumps to the third open document.
  document3(
    mac: [KeyBinding(_Key.digit3, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit3, alt: true)],
  ),

  /// Jumps to the fourth open document.
  document4(
    mac: [KeyBinding(_Key.digit4, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit4, alt: true)],
  ),

  /// Jumps to the fifth open document.
  document5(
    mac: [KeyBinding(_Key.digit5, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit5, alt: true)],
  ),

  /// Jumps to the sixth open document.
  document6(
    mac: [KeyBinding(_Key.digit6, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit6, alt: true)],
  ),

  /// Jumps to the seventh open document.
  document7(
    mac: [KeyBinding(_Key.digit7, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit7, alt: true)],
  ),

  /// Jumps to the eighth open document.
  document8(
    mac: [KeyBinding(_Key.digit8, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit8, alt: true)],
  ),

  /// Jumps to the ninth open document.
  document9(
    mac: [KeyBinding(_Key.digit9, meta: true, alt: true)],
    windows: [KeyBinding(_Key.digit9, alt: true)],
  ),

  /// Shows or hides the sidebar (FmWindow `k.sidebar`, moved to ⌃⌘S on
  /// macOS by G44).
  toggleSidebar(
    mac: [KeyBinding(_Key.keyS, meta: true, control: true)],
    windows: [KeyBinding(_Key.keyS, control: true, alt: true)],
  ),

  /// Shows or hides the right panel (FmWindow `k.panel`).
  togglePanel(
    mac: [KeyBinding(_Key.keyP, meta: true, alt: true)],
    windows: [KeyBinding(_Key.keyP, control: true, alt: true)],
  ),

  /// Undoes the last change (FmWindow `k.undo`).
  undo(
    mac: [KeyBinding(_Key.keyZ, meta: true)],
    windows: [KeyBinding(_Key.keyZ, control: true)],
  ),

  /// Redoes the last undone change (FmWindow `k.redo`).
  redo(
    mac: [KeyBinding(_Key.keyZ, meta: true, shift: true)],
    windows: [KeyBinding(_Key.keyY, control: true)],
  ),

  /// Finds text in the document (a11-3).
  find(
    mac: [KeyBinding(_Key.keyF, meta: true)],
    windows: [KeyBinding(_Key.keyF, control: true)],
  ),

  /// Moves to a page by number or label (a11-3, G30).
  goToPage(
    mac: [KeyBinding(_Key.keyG, meta: true)],
    windows: [KeyBinding(_Key.keyG, control: true)],
  ),

  /// Zooms in (FmWindow `k.zoomIn`): the `=` key, which carries `+`, with
  /// or without Shift, or the numpad `+`.
  zoomIn(
    mac: [
      KeyBinding(_Key.equal, meta: true, keyCap: '+'),
      KeyBinding(_Key.equal, meta: true, shift: true),
      KeyBinding(_Key.numpadAdd, meta: true),
    ],
    windows: [
      KeyBinding(_Key.equal, control: true, keyCap: '+'),
      KeyBinding(_Key.equal, control: true, shift: true),
      KeyBinding(_Key.numpadAdd, control: true),
    ],
  ),

  /// Zooms out (FmWindow `k.zoomOut`).
  zoomOut(
    mac: [
      KeyBinding(_Key.minus, meta: true),
      KeyBinding(_Key.numpadSubtract, meta: true),
    ],
    windows: [
      KeyBinding(_Key.minus, control: true),
      KeyBinding(_Key.numpadSubtract, control: true),
    ],
  ),

  /// Fits the page in the window (a2-2, a11-3).
  fitPage(
    mac: [KeyBinding(_Key.digit0, meta: true)],
    windows: [KeyBinding(_Key.digit0, control: true)],
  ),

  /// Shows the page at its actual size (a2-2).
  actualSize(
    mac: [KeyBinding(_Key.digit1, meta: true)],
    windows: [KeyBinding(_Key.digit1, control: true)],
  ),

  /// Fits the page width in the window (a2-2).
  fitWidth(
    mac: [KeyBinding(_Key.digit2, meta: true)],
    windows: [KeyBinding(_Key.digit2, control: true)],
  ),

  /// Turns reading mode on or off (a11-3).
  readingMode(
    mac: [KeyBinding(_Key.period, meta: true)],
    windows: [KeyBinding(_Key.period, control: true)],
  ),

  /// Starts the presentation (FmWindow `k.present`).
  present(
    mac: [KeyBinding(_Key.keyL, meta: true)],
    windows: [KeyBinding(_Key.keyL, control: true)],
  ),

  /// Adds a bookmark at the current view (FmSidebar `kBookmark`, a2-3x).
  addBookmark(
    mac: [KeyBinding(_Key.keyB, meta: true)],
    windows: [KeyBinding(_Key.keyB, control: true)],
  ),

  /// Moves to the next page (a11-3), while the canvas has focus.
  nextPage(
    mac: [KeyBinding(_Key.arrowRight)],
    windows: [KeyBinding(_Key.arrowRight)],
    scope: ShortcutScope.canvas,
  ),

  /// Moves to the previous page, while the canvas has focus; the pair of
  /// [nextPage] for the status bar's Previous page.
  previousPage(
    mac: [KeyBinding(_Key.arrowLeft)],
    windows: [KeyBinding(_Key.arrowLeft)],
    scope: ShortcutScope.canvas,
  ),

  /// View: the Select tool (FmWindow `k.v`).
  selectTool(
    mac: [KeyBinding(_Key.keyV)],
    windows: [KeyBinding(_Key.keyV)],
    modes: {FermanMode.view},
  ),

  /// View: the Hand tool (FmWindow `k.h`).
  handTool(
    mac: [KeyBinding(_Key.keyH)],
    windows: [KeyBinding(_Key.keyH)],
    modes: {FermanMode.view},
  ),

  /// View: the Marquee zoom tool (FmWindow `k.z`, a2-2).
  marqueeZoom(
    mac: [KeyBinding(_Key.keyZ)],
    windows: [KeyBinding(_Key.keyZ)],
    modes: {FermanMode.view},
  ),

  /// Edit: the Edit text tool (FmWindow `k.t`).
  editText(
    mac: [KeyBinding(_Key.keyT)],
    windows: [KeyBinding(_Key.keyT)],
    modes: {FermanMode.edit},
  ),

  /// Edit: the Add text tool (FmWindow `k.shiftT`).
  addText(
    mac: [KeyBinding(_Key.keyT, shift: true)],
    windows: [KeyBinding(_Key.keyT, shift: true)],
    modes: {FermanMode.edit},
  ),

  /// Edit: the Add image tool (FmWindow `k.i`).
  addImage(
    mac: [KeyBinding(_Key.keyI)],
    windows: [KeyBinding(_Key.keyI)],
    modes: {FermanMode.edit},
  ),

  /// Edit: the Link tool (FmWindow `k.l`).
  link(
    mac: [KeyBinding(_Key.keyL)],
    windows: [KeyBinding(_Key.keyL)],
    modes: {FermanMode.edit},
  ),

  /// Edit: Find & replace (FmWindow `k.replace`).
  findAndReplace(
    mac: [KeyBinding(_Key.keyF, meta: true, alt: true)],
    windows: [KeyBinding(_Key.keyH, control: true)],
    modes: {FermanMode.edit},
  ),

  /// Comment: the Select tool (`AnnotationTool.select`, V).
  annotationSelect(
    mac: [KeyBinding(_Key.keyV)],
    windows: [KeyBinding(_Key.keyV)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Highlight (H).
  highlight(
    mac: [KeyBinding(_Key.keyH)],
    windows: [KeyBinding(_Key.keyH)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Underline (U).
  underline(
    mac: [KeyBinding(_Key.keyU)],
    windows: [KeyBinding(_Key.keyU)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Strikethrough (S).
  strikethrough(
    mac: [KeyBinding(_Key.keyS)],
    windows: [KeyBinding(_Key.keyS)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Note (N).
  note(
    mac: [KeyBinding(_Key.keyN)],
    windows: [KeyBinding(_Key.keyN)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Text (X).
  textBox(
    mac: [KeyBinding(_Key.keyX)],
    windows: [KeyBinding(_Key.keyX)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Callout (C).
  callout(
    mac: [KeyBinding(_Key.keyC)],
    windows: [KeyBinding(_Key.keyC)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Draw (P).
  draw(
    mac: [KeyBinding(_Key.keyP)],
    windows: [KeyBinding(_Key.keyP)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Shapes (R).
  shapes(
    mac: [KeyBinding(_Key.keyR)],
    windows: [KeyBinding(_Key.keyR)],
    modes: {FermanMode.comment},
  ),

  /// Comment: Measure (M).
  measure(
    mac: [KeyBinding(_Key.keyM)],
    windows: [KeyBinding(_Key.keyM)],
    modes: {FermanMode.comment},
  ),

  /// Comment: shows or hides every comment (a11-3, a4-5).
  showComments(
    mac: [KeyBinding(_Key.keyH, meta: true, shift: true)],
    windows: [KeyBinding(_Key.keyH, control: true, shift: true)],
    modes: {FermanMode.comment},
  ),

  /// Fill & Sign: the next form field (FmWindow `k.tab`), in the canvas.
  nextField(
    mac: [KeyBinding(_Key.tab)],
    windows: [KeyBinding(_Key.tab)],
    modes: {FermanMode.sign},
    scope: ShortcutScope.canvas,
  ),

  /// Fill & Sign: the previous form field (FmWindow `k.shiftTab`), in the
  /// canvas.
  previousField(
    mac: [KeyBinding(_Key.tab, shift: true)],
    windows: [KeyBinding(_Key.tab, shift: true)],
    modes: {FermanMode.sign},
    scope: ShortcutScope.canvas,
  ),

  /// Fill & Sign: today's date (a11-3).
  todaysDate(
    mac: [KeyBinding(_Key.keyD, shift: true)],
    windows: [KeyBinding(_Key.keyD, shift: true)],
    modes: {FermanMode.sign},
  ),

  /// Fill & Sign: adds a signature (a11-2, a11-3; moved off ⌥⌘S by G44).
  addSignature(
    mac: [KeyBinding(_Key.keyS, shift: true)],
    windows: [KeyBinding(_Key.keyS, shift: true)],
    modes: {FermanMode.sign},
  ),

  /// Organize: rotates the selected pages left (FmWindow `k.rotL`).
  rotateLeft(
    mac: [KeyBinding(_Key.bracketLeft, meta: true)],
    windows: [KeyBinding(_Key.bracketLeft, control: true)],
    modes: {FermanMode.organize},
  ),

  /// Organize: rotates the selected pages right (FmWindow `k.rotR`).
  rotateRight(
    mac: [KeyBinding(_Key.bracketRight, meta: true)],
    windows: [KeyBinding(_Key.bracketRight, control: true)],
    modes: {FermanMode.organize},
  ),

  /// Organize: duplicates the selected pages (a11-3, a14-1d).
  duplicatePages(
    mac: [KeyBinding(_Key.keyD, meta: true)],
    windows: [KeyBinding(_Key.keyD, control: true)],
    modes: {FermanMode.organize},
  ),

  /// Organize: extracts the selected pages (a11-3, a14-1d).
  extractPages(
    mac: [KeyBinding(_Key.keyE, meta: true, alt: true)],
    windows: [KeyBinding(_Key.keyE, control: true, alt: true)],
    modes: {FermanMode.organize},
  ),

  /// Organize: inserts pages from a file (a14-1d).
  insertFromFile(
    mac: [KeyBinding(_Key.keyI, meta: true)],
    windows: [KeyBinding(_Key.keyI, control: true)],
    modes: {FermanMode.organize},
  ),

  /// Organize: deletes the selected pages (FmWindow `k.del`, a14-1d), in
  /// the page grid.
  deletePages(
    mac: [KeyBinding(_Key.backspace), KeyBinding(_Key.delete)],
    windows: [KeyBinding(_Key.delete), KeyBinding(_Key.backspace)],
    modes: {FermanMode.organize},
    scope: ShortcutScope.canvas,
  ),

  /// Organize: selects every page (a6 note, a14-1d), in the page grid.
  selectAllPages(
    mac: [KeyBinding(_Key.keyA, meta: true)],
    windows: [KeyBinding(_Key.keyA, control: true)],
    modes: {FermanMode.organize},
    scope: ShortcutScope.canvas,
  ),

  /// Organize: moves the selected pages up (a6 note, a14-1d), in the page
  /// grid.
  movePagesUp(
    mac: [KeyBinding(_Key.arrowUp, meta: true, alt: true)],
    windows: [KeyBinding(_Key.arrowUp, control: true, alt: true)],
    modes: {FermanMode.organize},
    scope: ShortcutScope.canvas,
  ),

  /// Organize: moves the selected pages down (a6 note), in the page grid.
  movePagesDown(
    mac: [KeyBinding(_Key.arrowDown, meta: true, alt: true)],
    windows: [KeyBinding(_Key.arrowDown, control: true, alt: true)],
    modes: {FermanMode.organize},
    scope: ShortcutScope.canvas,
  ),

  /// Protect: the Redact tool (FmWindow `k.r`).
  redact(
    mac: [KeyBinding(_Key.keyR)],
    windows: [KeyBinding(_Key.keyR)],
    modes: {FermanMode.protect},
  ),

  /// Protect: Find & redact (a11-3).
  findAndRedact(
    mac: [KeyBinding(_Key.keyR, meta: true, shift: true)],
    windows: [KeyBinding(_Key.keyR, control: true, shift: true)],
    modes: {FermanMode.protect},
  ),

  /// Minimizes the window (macOS ⌘M; WindowChrome's window commands).
  minimizeWindow(mac: [KeyBinding(_Key.keyM, meta: true)], windows: []),

  /// Closes the window (Alt+F4 on Windows and Linux).
  closeWindow(mac: [], windows: [KeyBinding(_Key.f4, alt: true)]),

  /// Quits Ferman (⌘Q on macOS, Ctrl+Q on Linux).
  quit(
    mac: [KeyBinding(_Key.keyQ, meta: true)],
    windows: [],
    linux: [KeyBinding(_Key.keyQ, control: true)],
  );

  new({
    required this.mac,
    required this.windows,
    List<KeyBinding>? linux,
    this.modes,
    this.scope = ShortcutScope.window,
  }) : linuxOverride = linux;

  /// The bindings on macOS; the first is the one shown.
  final List<KeyBinding> mac;

  /// The bindings on Windows; the first is the one shown.
  final List<KeyBinding> windows;

  /// The bindings on Linux where they differ from [windows]; null when
  /// Linux uses the Windows ones.
  final List<KeyBinding>? linuxOverride;

  /// The modes the command works in; null for every mode.
  final Set<FermanMode>? modes;

  /// Where the command's keys apply.
  final ShortcutScope scope;

  /// The bindings on Linux: the Windows ones unless the command has its
  /// own.
  List<KeyBinding> get linux => linuxOverride ?? windows;

  /// The bindings on [platform]; the first is the one shown.
  List<KeyBinding> bindingsFor(ShortcutPlatform platform) => switch (platform) {
    ShortcutPlatform.mac => mac,
    ShortcutPlatform.windows => windows,
    ShortcutPlatform.linux => linux,
  };

  /// The key caps tooltips and menus show for this command on [platform],
  /// or null when it has no key there.
  List<String>? caps(ShortcutPlatform platform) {
    final bindings = bindingsFor(platform);
    return bindings.isEmpty ? null : bindings.first.caps(platform);
  }

  /// Whether the command's keys work in [mode].
  bool appliesIn(FermanMode mode) => modes?.contains(mode) ?? true;

  /// The commands of the window itself: minimize, close and quit. The
  /// window frame binds them on every screen (`WindowCommandScope`), so
  /// they are left out of [shortcutsFor].
  static const Set<ShellCommand> windowCommands = {
    minimizeWindow,
    closeWindow,
    quit,
  };

  /// The [Shortcuts] map of every command of [scope] that works in [mode],
  /// on [platform], except the [windowCommands].
  static Map<ShortcutActivator, Intent> shortcutsFor(
    ShortcutPlatform platform,
    FermanMode mode, {
    ShortcutScope scope = ShortcutScope.window,
  }) => {
    for (final command in values)
      if (command.scope == scope &&
          command.appliesIn(mode) &&
          !windowCommands.contains(command))
        for (final binding in command.bindingsFor(platform))
          binding.activator: ShellCommandIntent(
            command,
            plain: binding.isPlain,
          ),
  };

  /// Every collision of the table on [platform]: two commands bound to the
  /// same keys in a mode where both work. Canvas keys collide with window
  /// keys too, since the canvas is inside the window. Empty when the table
  /// is sound.
  static List<String> conflicts(ShortcutPlatform platform) =>
      conflictsIn(platform, [
        for (final command in values)
          (
            name: command.name,
            bindings: command.bindingsFor(platform),
            modes: command.modes,
          ),
      ]);

  /// The collisions among [entries] on [platform], as [conflicts] finds
  /// them in the table: two entries bound to the same keys in a mode where
  /// both work (null modes: every mode). The scope is not looked at, so a
  /// canvas key collides with a window key.
  @visibleForTesting
  static List<String> conflictsIn(
    ShortcutPlatform platform,
    Iterable<ShortcutEntry> entries,
  ) {
    bool appliesIn(ShortcutEntry entry, FermanMode mode) =>
        entry.modes?.contains(mode) ?? true;
    final seen = <String, List<ShortcutEntry>>{};
    final problems = <String>[];
    for (final entry in entries) {
      for (final binding in entry.bindings) {
        final others = seen.putIfAbsent(binding.identity, () => []);
        for (final other in others) {
          final shared = FermanMode.values.where(
            (mode) => appliesIn(other, mode) && appliesIn(entry, mode),
          );
          if (shared.isNotEmpty) {
            problems.add(
              '${platform.name}: ${binding.caps(platform).join(' ')} is '
              'both ${other.name} and ${entry.name} in '
              '${shared.map((mode) => mode.id).join(', ')}',
            );
          }
        }
        if (!others.contains(entry)) others.add(entry);
      }
    }
    return problems;
  }
}

/// A command as [ShellCommand.conflictsIn] checks it: its name, its
/// bindings on one system and the modes it works in (null: every mode).
typedef ShortcutEntry = ({
  String name,
  List<KeyBinding> bindings,
  Set<FermanMode>? modes,
});

/// The intent of a [ShellCommand] key, bound through the shortcut table.
class ShellCommandIntent extends Intent {
  /// The intent of [command], from a [plain] single-key binding or not.
  const new(this.command, {this.plain = false});

  /// The command the keys stand for.
  final ShellCommand command;

  /// Whether the keys were a single key without ⌘, Ctrl or Alt, which does
  /// nothing while the user types in a text field.
  final bool plain;
}

/// Runs the handler of a [ShellCommandIntent]'s command.
///
/// A command without a handler is disabled, so its keys are not consumed
/// and reach the widgets above (a disabled Tab still moves focus). A
/// single-key command is disabled while focus is in a text field, where the
/// key types a character.
class ShellCommandAction extends Action<ShellCommandIntent> {
  /// An action with [handlers], one per working command.
  new(this.handlers);

  /// What each working command does.
  final Map<ShellCommand, VoidCallback> handlers;

  /// Whether the primary focus is in an editable text field.
  static bool get typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;

  @override
  bool isEnabled(ShellCommandIntent intent) =>
      handlers.containsKey(intent.command) && !(intent.plain && typing);

  @override
  Object? invoke(ShellCommandIntent intent) {
    handlers[intent.command]?.call();
    return null;
  }
}
