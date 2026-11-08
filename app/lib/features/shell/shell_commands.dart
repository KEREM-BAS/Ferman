import 'dart:async';

import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart'
    show AnnotationTool, FermanMode;
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/extract_pages_dialog.dart';
import 'package:ferman/features/organize/insert_file_dialog.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/save/document_closer.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/document_parts.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_palette.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcut_sheet.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/signatures/add_signature_dialog.dart';
import 'package:ferman/features/signatures/sign_tools.dart';
import 'package:ferman/features/tools/print_dialog.dart';
import 'package:ferman/features/tools/tools_state.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Binds the shortcut table's window-wide keys (`ShortcutScope.window`) for
/// the current mode and system around [child], through [Shortcuts] and
/// [Actions].
///
/// The title bar's content and the screen below it each sit in one, so the
/// keys work wherever focus is. Commands that work get a handler: Settings
/// when [onOpenSettings] is given, Open while the engine can open files
/// ([openFiles]) and, in the editor, the sidebar and panel toggles, moving
/// between the open documents and, with a document open
/// (`viewerProvider`), zoom, the fits, page turns, Go to page, Find and the
/// View tools; Save with unsaved changes, Save as and Save a copy
/// (`documentSaverProvider`), and undo and redo while the history has a
/// step for them (`documentEditorProvider`). The command palette
/// ([ShellPalette]) and the cheat sheet ([ShortcutSheet]) work everywhere;
/// on the start screen ([home]) only they, Settings, Open and Create PDF
/// do. The keys come from `shortcutBindingsProvider`, the user's changes
/// included.
/// Every other command is
/// disabled, so its keys pass through. The window's own commands (⌘M, ⌘Q,
/// Alt+F4, Ctrl+Q) are the window frame's, on every screen
/// ([WindowCommandScope]).
class ShellCommandScope extends ConsumerWidget {
  /// Binds the shell's keys around [child].
  const new({
    required this.child,
    super.key,
    this.onOpenSettings,
    this.home = false,
  });

  /// The widgets the keys work in.
  final Widget child;

  /// Opens Settings (⌘, or Ctrl+,); null leaves the command disabled.
  final VoidCallback? onOpenSettings;

  /// Whether the start screen shows instead of the editor: the editor's
  /// commands (sidebar, panel, documents) are disabled, and only Settings
  /// and Open work.
  final bool home;

  /// The handlers of the commands that work.
  static Map<ShellCommand, VoidCallback> handlersFor(
    WidgetRef ref, {
    VoidCallback? onOpenSettings,
    VoidCallback? onOpenFiles,
    bool home = false,
  }) {
    // Whatever lets files open lets a new one be made.
    VoidCallback? createPdf;
    if (onOpenFiles != null) {
      createPdf = () => ref
          .read(organizeDialogProvider.notifier)
          .show(const CreatePdfDialog());
    }
    final dialogs = ref.read(organizeDialogProvider.notifier);
    void palette() =>
        dialogs.show(ShellPalette(home: home, onOpenSettings: onOpenSettings));
    void sheet() => dialogs.show(const ShortcutSheet());
    if (home) {
      return {
        ShellCommand.commandPalette: palette,
        ShellCommand.keyboardShortcuts: sheet,
        ShellCommand.settings: ?onOpenSettings,
        ShellCommand.open: ?onOpenFiles,
        ShellCommand.createPdf: ?createPdf,
      };
    }
    final documents = ref.read(shellDocumentsProvider.notifier);
    final count = ref.read(shellDocumentsProvider).documents.length;
    final active = ref.read(shellDocumentsProvider).active;
    final panels = ref.read(shellPanelsProvider);
    final viewer = ref.read(viewerProvider.notifier);
    final editor = ref.read(documentEditorProvider.notifier);
    final links = ref.read(linkToolProvider.notifier);
    final edits = ref.read(documentEditorProvider);
    final saver = ref.read(documentSaverProvider.notifier);
    return {
      // Like the mode bar's toggles: a panel that stepped aside in a narrow
      // window comes back; one that cannot fit even alone leaves its keys
      // unbound (G21).
      if (panels.sidebarAvailable)
        ShellCommand.toggleSidebar: () =>
            toggleShellSide(ref, ShellSide.sidebar),
      if (panels.panelAvailable)
        ShellCommand.togglePanel: () => toggleShellSide(ref, ShellSide.panel),
      ShellCommand.commandPalette: palette,
      ShellCommand.keyboardShortcuts: sheet,
      ShellCommand.settings: ?onOpenSettings,
      ShellCommand.open: ?onOpenFiles,
      ShellCommand.createPdf: ?createPdf,
      if (active?.path case final path?)
        ShellCommand.closeDocument: () =>
            unawaited(ref.read(documentCloserProvider.notifier).close(path)),
      if (count > 1) ...{
        ShellCommand.nextDocument: documents.activateNext,
        ShellCommand.showAllDocuments: ref
            .read(showAllDocumentsRequestProvider.notifier)
            .request,
      },
      if (active?.document != null)
        ShellCommand.documentProperties: ref
            .read(documentPropertiesRequestProvider.notifier)
            .request,
      if (active?.document != null && ref.read(printRefusalProvider) == null)
        ShellCommand.printDocument: () => showPrintDialog(ref),
      for (var i = 0; i < documentJumps.length && i < count; i++)
        documentJumps[i]: () => documents.activate(i),
      if (ref.read(viewerProvider) != null) ...{
        ShellCommand.zoomIn: viewer.zoomIn,
        ShellCommand.zoomOut: viewer.zoomOut,
        ShellCommand.fitPage: () => viewer.fit(ZoomFit.page),
        ShellCommand.fitWidth: () => viewer.fit(ZoomFit.width),
        ShellCommand.actualSize: () => viewer.zoomTo(1),
        ShellCommand.nextPage: viewer.nextPage,
        ShellCommand.previousPage: viewer.previousPage,
        ShellCommand.goToPage: ref
            .read(pageFieldRequestProvider.notifier)
            .request,
        ShellCommand.find: ref.read(findProvider.notifier).open,
        ShellCommand.addBookmark: () => addBookmark(ref),
        ShellCommand.editText: () => links.show(on: false),
        ShellCommand.link: links.toggle,
        ShellCommand.addLink: links.addSelection,
        ShellCommand.selectTool: () => viewer.setTool(ViewerTool.select),
        ShellCommand.handTool: () => viewer.setTool(ViewerTool.hand),
        ShellCommand.marqueeZoom: () => viewer.setTool(ViewerTool.marquee),
        if (edits.canUndo) ShellCommand.undo: () => unawaited(editor.undo()),
        if (edits.canRedo) ShellCommand.redo: () => unawaited(editor.redo()),
        if (ref.read(shellModeProvider) == FermanMode.organize &&
            !ref.read(cropShowingProvider))
          ..._organizeHandlers(ref),
        if (ref.read(shellModeProvider) == FermanMode.comment)
          ..._commentHandlers(ref),
        if (ref.read(shellModeProvider) == FermanMode.sign)
          ..._fillHandlers(ref, panel: panels.panel),
        if (ref.read(shellModeProvider) == FermanMode.sign &&
            ref.read(commentRefusalProvider) == null)
          ShellCommand.addSignature: () =>
              showAddSignatureDialog(ref, yourName: yourNameOf(ref)),
      },
      // Typing not yet committed counts too: Save commits it first.
      if (active?.document != null && (active!.unsaved || edits.active != null))
        ShellCommand.save: () => unawaited(saver.save()),
      if (active?.document != null) ...{
        ShellCommand.saveAs: saver.openSheet,
        ShellCommand.saveCopy: () => saver.openSheet(copy: true),
      },
    };
  }

  /// Comment's tool keys (a4-1), not while comments cannot be added, and Show
  /// comments (⇧⌘H).
  static Map<ShellCommand, VoidCallback> _commentHandlers(WidgetRef ref) {
    final tool = ref.read(commentToolProvider.notifier);
    return {
      ShellCommand.annotationSelect: () => tool.pick(AnnotationTool.select),
      if (ref.read(commentRefusalProvider) == null) ...{
        ShellCommand.highlight: () => tool.pick(AnnotationTool.highlight),
        ShellCommand.underline: () => tool.pick(AnnotationTool.underline),
        ShellCommand.strikethrough: () =>
            tool.pick(AnnotationTool.strikethrough),
        ShellCommand.note: () => tool.pick(AnnotationTool.note),
        ShellCommand.textBox: () => tool.pick(AnnotationTool.text),
        ShellCommand.callout: () => tool.pick(AnnotationTool.callout),
        ShellCommand.draw: () => tool.pick(AnnotationTool.pen),
        ShellCommand.shapes: () => tool.pick(AnnotationTool.shapes),
      },
      if (ref.read(openDocumentProvider)?.layersSwitchable ?? false)
        ShellCommand.showComments: () => unawaited(
          ref
              .read(commentsShownProvider.notifier)
              .show(visible: !ref.read(commentsShownProvider).visible),
        ),
    };
  }

  /// Fill & Sign's keys: Tab and ⇧Tab between a form's fields, and Fill
  /// anything's tools, live only with its panel open (M4 decision 24).
  static Map<ShellCommand, VoidCallback> _fillHandlers(
    WidgetRef ref, {
    required bool panel,
  }) {
    final form = ref.read(documentFormProvider).value;
    if (form == null) return const {};
    final session = ref.read(formSessionProvider.notifier);
    final tools = ref.read(fillToolsStateProvider);
    final pick = ref.read(fillToolsStateProvider.notifier).pick;
    return {
      if (form.fields.isNotEmpty) ...{
        ShellCommand.nextField: () => session.move(form, 1),
        ShellCommand.previousField: () => session.move(form, -1),
      },
      if (panel &&
          tools.effective(form) != FillTool.fields &&
          ref.read(fillRefusalProvider) == null) ...{
        ShellCommand.fillText: () => pick(FillTool.text),
        ShellCommand.fillCheck: () => pick(FillTool.check),
        ShellCommand.fillCross: () => pick(FillTool.cross),
        ShellCommand.fillDot: () => pick(FillTool.dot),
        ShellCommand.todaysDate: () => pick(FillTool.date),
      },
    };
  }

  /// Organize's keys on the selection (a6-1, a14-1d).
  static Map<ShellCommand, VoidCallback> _organizeHandlers(WidgetRef ref) {
    final document = ref.read(openDocumentProvider);
    final selected = ref.read(selectedPagesProvider);
    final commands = ref.read(pageCommandsProvider.notifier);
    final changes = ref.read(organizeRefusalProvider) == null;
    return {
      if (document != null) ...{
        ShellCommand.selectAllPages: () =>
            ref.read(pageSelectionProvider.notifier).all([
              for (var i = 0; i < document.pages.length; i++)
                document.pageHandle(i),
            ]),
        ShellCommand.extractPages: () => showExtractPagesDialog(
          ref,
          document,
          ref.read(shellDocumentsProvider).active?.name ?? '',
          organizeSelection(ref),
        ),
        if (changes)
          ShellCommand.insertFromFile: () =>
              showInsertFileDialog(ref, document, organizeSelection(ref)),
      },
      if (changes && selected.isNotEmpty) ...{
        ShellCommand.rotateLeft: () => unawaited(commands.rotate(-1)),
        ShellCommand.rotateRight: () => unawaited(commands.rotate(1)),
        ShellCommand.duplicatePages: () => unawaited(commands.duplicate()),
        ShellCommand.movePagesUp: () => unawaited(commands.moveUp()),
        ShellCommand.movePagesDown: () => unawaited(commands.moveDown()),
        if (ref.read(deleteRefusalProvider) == null)
          ShellCommand.deletePages: () => unawaited(commands.delete()),
      },
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(shortcutBindingsProvider);
    final mode = ref.watch(shellModeProvider);
    // Rebuild the handlers when the documents or the panels' room change.
    if (!home) {
      ref
        ..watch(shellDocumentsProvider)
        ..watch(shellPanelsProvider)
        ..watch(viewerProvider.select((view) => view != null))
        ..watch(documentEditorProvider)
        ..watch(printRefusalProvider);
      if (mode == FermanMode.organize) {
        ref
          ..watch(selectedPagesProvider)
          ..watch(organizeRefusalProvider);
      }
      if (mode == FermanMode.comment) {
        ref
          ..watch(commentRefusalProvider)
          ..watch(commentsShownProvider);
      }
      if (mode == FermanMode.sign) {
        ref
          ..watch(documentFormProvider)
          ..watch(fillToolsStateProvider)
          ..watch(fillRefusalProvider)
          ..watch(commentRefusalProvider);
      }
    }
    return Actions(
      actions: {
        ShellCommandIntent: ShellCommandAction(
          handlersFor(
            ref,
            onOpenSettings: onOpenSettings,
            onOpenFiles: openFiles(context, ref),
            home: home,
          ),
        ),
      },
      child: Shortcuts(shortcuts: bindings.shortcutsFor(mode), child: child),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        ObjectFlagProperty<VoidCallback>.has('onOpenSettings', onOpenSettings),
      )
      ..add(FlagProperty('home', value: home, ifTrue: 'home'));
  }
}

/// The commands that show the first nine documents (⌘1…⌘9, a1-10).
const List<ShellCommand> documentJumps = [
  ShellCommand.document1,
  ShellCommand.document2,
  ShellCommand.document3,
  ShellCommand.document4,
  ShellCommand.document5,
  ShellCommand.document6,
  ShellCommand.document7,
  ShellCommand.document8,
  ShellCommand.document9,
];

/// The command registry's other half: the commands no screen handles yet,
/// each with the feature that holds it back. Every other command has a
/// handler in [ShellCommandScope.handlersFor] or [WindowCommandScope] (a
/// test keeps the two halves complete); the palette shows these disabled
/// with the feature's reason (G10).
const Map<ShellCommand, Feature> unfinishedCommands = {
  ShellCommand.readingMode: Feature.darkReadingMode,
  ShellCommand.present: Feature.presentation,
  ShellCommand.addText: Feature.addingTextBoxes,
  ShellCommand.addImage: Feature.addingImages,
  ShellCommand.findAndReplace: Feature.findAndReplace,
  ShellCommand.measure: Feature.measure,
  ShellCommand.redact: Feature.redaction,
  ShellCommand.findAndRedact: Feature.redaction,
};

/// Why opening PDFs is disabled, or null when it works: the engine's
/// problem (G101), or the web build, whose engine is a stub until P5.
String? openFilesDisabledReason(BuildContext context, WidgetRef ref) {
  if (ref.watch(engineProblemProvider) != null) {
    return AppLocalizations.of(context).startEngineUnavailableTitle;
  }
  if (ref.watch(engineStatusProvider).error case EngineUnavailableException(
    reason: EngineUnavailableReason.unsupportedPlatform,
  )) {
    return Feature.openFilesOnWeb.disabledReason(context);
  }
  return null;
}

/// Opens PDFs through the system open panel (ADR 0018), or null while
/// opening is disabled ([openFilesDisabledReason]).
VoidCallback? openFiles(BuildContext context, WidgetRef ref) {
  if (openFilesDisabledReason(context, ref) != null) return null;
  final filter = AppLocalizations.of(context).openPdfFilter;
  return () => unawaited(
    ref.read(documentOpenerProvider.notifier).pick(filterLabel: filter),
  );
}

/// Binds the window's own commands from the shortcut table
/// ([ShellCommand.windowCommands]: ⌘M and ⌘Q on macOS, Alt+F4 on Windows
/// and Linux, Ctrl+Q on Linux) around [child], for every screen the window
/// frame holds: the start screen, first run, Settings and the editor.
///
/// Minimize minimizes [window]; close and quit close it, as the caption
/// buttons do, and the window asks about unsaved documents (G40).
/// Nothing is bound where the system draws the window
/// ([DesktopWindow.platform] null). The keys follow the shortcut table's
/// conventions for the system (`shortcutPlatformProvider`).
class WindowCommandScope extends ConsumerWidget {
  /// Binds [window]'s commands around [child].
  const new({required this.window, required this.child, super.key});

  /// The window the commands act on.
  final DesktopWindow window;

  /// The screens the keys work in.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (window.platform == null) return child;
    final platform = ref.watch(shortcutPlatformProvider);
    final handlers = <ShellCommand, VoidCallback>{
      ShellCommand.minimizeWindow: window.minimize,
      ShellCommand.windowMenu: window.showWindowMenu,
      ShellCommand.closeWindow: window.close,
      ShellCommand.quit: window.close,
    };
    return Actions(
      actions: {_WindowCommandIntent: _WindowCommandAction(handlers)},
      child: Shortcuts(
        shortcuts: {
          for (final command in ShellCommand.windowCommands)
            for (final binding in command.defaultsFor(platform))
              binding.activator: _WindowCommandIntent(command),
        },
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DesktopWindow>('window', window));
  }
}

/// A window command's keys. A type of its own, so the editor's
/// [ShellCommandAction] below never answers for it.
class _WindowCommandIntent extends Intent {
  const new(this.command);

  final ShellCommand command;
}

class _WindowCommandAction extends Action<_WindowCommandIntent> {
  new(this.handlers);

  final Map<ShellCommand, VoidCallback> handlers;

  @override
  bool isEnabled(_WindowCommandIntent intent) =>
      handlers.containsKey(intent.command);

  @override
  Object? invoke(_WindowCommandIntent intent) {
    handlers[intent.command]?.call();
    return null;
  }
}
