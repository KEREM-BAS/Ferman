import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/features/shell/shell_state.dart';
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
