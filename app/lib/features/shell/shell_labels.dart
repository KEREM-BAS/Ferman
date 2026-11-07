import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';

/// The shell's localized names for the design's data enums, whose labels
/// are copy and so live in the ARB files, not in the enums.
extension ShellLabels on AppLocalizations {
  /// The name of [mode] on its tab (FmWindow `modes`).
  String modeLabel(FermanMode mode) => switch (mode) {
    FermanMode.view => shellModeView,
    FermanMode.edit => shellModeEdit,
    FermanMode.comment => shellModeComment,
    FermanMode.sign => shellModeSign,
    FermanMode.organize => shellModeOrganize,
    FermanMode.convert => shellModeConvert,
    FermanMode.protect => shellModeProtect,
    FermanMode.tools => shellModeTools,
  };

  /// The name of the comment tool [tool] (FmWindow `annotTools`).
  String annotationToolLabel(AnnotationTool tool) => switch (tool) {
    AnnotationTool.select => shellToolSelect,
    AnnotationTool.highlight => shellAnnotationHighlight,
    AnnotationTool.underline => shellAnnotationUnderline,
    AnnotationTool.strikethrough => shellAnnotationStrikethrough,
    AnnotationTool.note => shellAnnotationNote,
    AnnotationTool.text => shellAnnotationText,
    AnnotationTool.callout => shellAnnotationCallout,
    AnnotationTool.pen => shellAnnotationDraw,
    AnnotationTool.shapes => shellAnnotationShapes,
    AnnotationTool.stamp => shellAnnotationStamp,
    AnnotationTool.measure => shellToolMeasure,
  };

  /// The name of the annotation colour [color].
  String annotationColorLabel(AnnotationColor color) => switch (color) {
    AnnotationColor.yellow => shellColorYellow,
    AnnotationColor.green => shellColorGreen,
    AnnotationColor.blue => shellColorBlue,
    AnnotationColor.pink => shellColorPink,
    AnnotationColor.orange => shellColorOrange,
    AnnotationColor.red => shellColorRed,
    AnnotationColor.ink => shellColorBlack,
  };

  /// The name and tooltip of the overflow button of a narrow tool row and
  /// the name of its menu (G21): "More tools".
  String get moreTools => shellMoreTools;

  /// The name of the sidebar tab [tab] (FmSidebar `tabOptions`).
  String sidebarTabLabel(SidebarTab tab) => switch (tab) {
    SidebarTab.pages => shellSidebarPages,
    SidebarTab.outline => shellSidebarOutline,
    SidebarTab.attachments => shellSidebarAttachments,
    SidebarTab.layers => shellSidebarLayers,
    SidebarTab.signatures => shellSidebarSignatures,
    SidebarTab.search => shellSidebarSearch,
  };
}

/// The names of the shortcut table's commands and the cheat sheet's
/// groups (a11-2, a11-3, a11-1j).
extension CommandLabels on AppLocalizations {
  /// The name of [command], with document numbers in [format].
  String commandLabel(ShellCommand command, RegionFormat format) =>
      switch (command) {
        ShellCommand.commandPalette => commandPalette,
        ShellCommand.settings => shellSettings,
        ShellCommand.keyboardShortcuts => commandShowShortcuts,
        ShellCommand.open => shellOpenFile,
        ShellCommand.createPdf => shellToolCreatePdf,
        ShellCommand.save => shellSave,
        ShellCommand.saveAs => saveAsTitle,
        ShellCommand.saveCopy => commandSaveCopy,
        ShellCommand.printDocument => shellToolPrint,
        ShellCommand.closeDocument => shellCloseDocument,
        ShellCommand.showAllDocuments => shellShowAllDocuments,
        ShellCommand.documentProperties => commandDocumentProperties,
        ShellCommand.nextDocument => commandNextDocument,
        ShellCommand.document1 ||
        ShellCommand.document2 ||
        ShellCommand.document3 ||
        ShellCommand.document4 ||
        ShellCommand.document5 ||
        ShellCommand.document6 ||
        ShellCommand.document7 ||
        ShellCommand.document8 ||
        ShellCommand.document9 => commandShowDocument(
          format.integer(command.index - ShellCommand.document1.index + 1),
        ),
        ShellCommand.toggleSidebar => shellToggleSidebar,
        ShellCommand.togglePanel => shellTogglePanel,
        ShellCommand.undo => shellUndo,
        ShellCommand.redo => shellRedo,
        ShellCommand.find => findField,
        ShellCommand.goToPage => commandGoToPage,
        ShellCommand.zoomIn => shellZoomIn,
        ShellCommand.zoomOut => shellZoomOut,
        ShellCommand.fitPage => shellFitPage,
        ShellCommand.actualSize => shellActualSize,
        ShellCommand.fitWidth => shellFitWidth,
        ShellCommand.readingMode => commandReadingMode,
        ShellCommand.present => shellToolPresent,
        ShellCommand.addBookmark => shellAddBookmark,
        ShellCommand.nextPage => shellNextPage,
        ShellCommand.previousPage => shellPreviousPage,
        ShellCommand.selectTool ||
        ShellCommand.annotationSelect => shellToolSelect,
        ShellCommand.handTool => shellToolHand,
        ShellCommand.marqueeZoom => shellToolMarqueeZoom,
        ShellCommand.editText => shellToolEditText,
        ShellCommand.addText => shellToolAddText,
        ShellCommand.addImage => shellToolAddImage,
        ShellCommand.link => shellToolLink,
        ShellCommand.addLink => linkAddTitle,
        ShellCommand.findAndReplace => shellToolFindReplace,
        ShellCommand.highlight => shellAnnotationHighlight,
        ShellCommand.underline => shellAnnotationUnderline,
        ShellCommand.strikethrough => shellAnnotationStrikethrough,
        ShellCommand.note => shellAnnotationNote,
        ShellCommand.textBox => shellAnnotationText,
        ShellCommand.callout => shellAnnotationCallout,
        ShellCommand.draw => shellAnnotationDraw,
        ShellCommand.shapes => shellAnnotationShapes,
        ShellCommand.measure => shellToolMeasure,
        ShellCommand.showComments => shellShowComments,
        ShellCommand.nextField => formNextField,
        ShellCommand.previousField => formPreviousField,
        ShellCommand.todaysDate => fillToolToday,
        ShellCommand.fillText => fillToolText,
        ShellCommand.fillCheck => fillToolCheck,
        ShellCommand.fillCross => fillToolCross,
        ShellCommand.fillDot => fillToolDot,
        ShellCommand.addSignature => signDialogTitle,
        ShellCommand.rotateLeft => shellToolRotateLeft,
        ShellCommand.rotateRight => shellToolRotateRight,
        ShellCommand.duplicatePages => shellToolDuplicate,
        ShellCommand.extractPages => shellToolExtract,
        ShellCommand.insertFromFile => commandInsertFromFile,
        ShellCommand.deletePages => commandDeletePages,
        ShellCommand.selectAllPages => commandSelectAllPages,
        ShellCommand.movePagesUp => commandMovePagesUp,
        ShellCommand.movePagesDown => commandMovePagesDown,
        ShellCommand.redact => shellToolRedact,
        ShellCommand.findAndRedact => shellToolFindRedact,
        ShellCommand.minimizeWindow => windowMinimize,
        ShellCommand.windowMenu => commandWindowMenu,
        ShellCommand.closeWindow => commandCloseWindow,
        ShellCommand.quit => commandQuit,
      };

  /// The heading of the cheat sheet's [group], before casing.
  String shortcutGroupLabel(ShortcutGroup group) => switch (group) {
    ShortcutGroup.general => shortcutsGroupGeneral,
    ShortcutGroup.navigate => shortcutsGroupNavigate,
    ShortcutGroup.edit => shellModeEdit,
    ShortcutGroup.comment => shellModeComment,
    ShortcutGroup.sign => shellModeSign,
    ShortcutGroup.organize => shellModeOrganize,
    ShortcutGroup.protect => shellModeProtect,
    ShortcutGroup.window => shortcutsGroupWindow,
  };
}
