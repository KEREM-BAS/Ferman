import 'package:ferman/features/gallery/sections/addition_sections.dart';
import 'package:ferman/features/gallery/sections/annotation_sections.dart';
import 'package:ferman/features/gallery/sections/core_sections.dart';
import 'package:ferman/features/gallery/sections/editing_sections.dart';
import 'package:ferman/features/gallery/sections/feedback_sections.dart';
import 'package:ferman/features/gallery/sections/fill_sign_sections.dart';
import 'package:ferman/features/gallery/sections/forms_sections.dart';
import 'package:ferman/features/gallery/sections/navigation_sections.dart';
import 'package:ferman/features/gallery/sections/overlay_sections.dart';
import 'package:ferman/features/gallery/sections/panel_page_sections.dart';
import 'package:flutter/widgets.dart';

/// The component groups of the spec (`group` in `component_spec.json`), in
/// the gallery's order, after the foundations the spec does not list.
///
/// The ids and the component names and sources below are design-system
/// identifiers and file references, not copy.
enum GalleryGroup {
  /// The foundations worth seeing that are not spec entries: the focus
  /// rings.
  foundation('foundation'),

  /// Core: icons, buttons, tooltip, key caps, badge.
  core('core'),

  /// Feedback: banner, progress, spinner, task, toast.
  feedback('feedback'),

  /// Forms: the field and its controls, the pickers, the popover.
  forms('forms'),

  /// Navigation: mode tabs, segmented control, toolbar, tool button.
  navigation('navigation'),

  /// Overlays: command palette, dialog, menu, scrim (inline).
  overlays('overlays'),

  /// Panels: the panel section.
  panels('panels'),

  /// Pages: the page thumbnail.
  pages('pages'),

  /// Editing: page marks, search bar, text edit box, caret.
  editing('editing'),

  /// Annotations: the tool row, highlight, sticky note, stamp.
  annotations('annotations'),

  /// Fill and sign: form fields and the signature pad.
  fillSign('fill-sign'),

  /// Empty states: the drop zone.
  empty('empty'),

  /// The DS additions: tabs, window chrome, save indicator, date picker,
  /// mention list, comment card, thumbnail badges, FmNumber.
  additions('additions');

  new(this.id);

  /// The group's name in the spec.
  final String id;
}

/// One section of the gallery: a component of the spec (or a foundation),
/// where it comes from in the design, and how to draw its samples.
@immutable
final class GalleryEntry {
  /// The section for the component [name].
  const new({
    required this.name,
    required this.group,
    required this.source,
    required this.builder,
    this.flutterClass,
  });

  /// The design-system name (`name` in the spec).
  final String name;

  /// The spec group.
  final GalleryGroup group;

  /// Where the component is drawn in the design export, to compare with.
  final String source;

  /// The Flutter name when it differs from [name] (the enums and
  /// constants), else null.
  final String? flutterClass;

  /// Draws the samples: every variant, size and state the spec lists.
  final WidgetBuilder builder;
}

const String _bundle = '_ds_bundle.js';

/// Every section of the gallery, in group order: the 56 components of the
/// component spec and the foundations.
final List<GalleryEntry> galleryEntries = [
  const GalleryEntry(
    name: 'FocusRing',
    group: GalleryGroup.foundation,
    source: 'tokens/effects.css · --focus-ring, --focus-ring-inset (G22)',
    builder: focusRingSection,
  ),
  const GalleryEntry(
    name: 'Icon',
    group: GalleryGroup.core,
    source: '$_bundle · components/core/Icon.jsx, lines 70–260',
    builder: iconSection,
  ),
  const GalleryEntry(
    name: 'ICON_PATHS',
    flutterClass: 'IconName',
    group: GalleryGroup.core,
    source:
        '$_bundle · components/core/Icon.jsx, lines 70–260 · '
        'icon_name.g.dart',
    builder: iconPathsSection,
  ),
  const GalleryEntry(
    name: 'Button',
    group: GalleryGroup.core,
    source: '$_bundle · components/core/Button.jsx, lines 378–414',
    builder: buttonSection,
  ),
  const GalleryEntry(
    name: 'IconButton',
    group: GalleryGroup.core,
    source: '$_bundle · components/core/IconButton.jsx, lines 481–517',
    builder: iconButtonSection,
  ),
  const GalleryEntry(
    name: 'Tooltip',
    group: GalleryGroup.core,
    source: '$_bundle · components/core/Tooltip.jsx, lines 434–479',
    builder: tooltipSection,
  ),
  const GalleryEntry(
    name: 'Kbd',
    group: GalleryGroup.core,
    source: '$_bundle · components/core/Kbd.jsx, lines 416–432',
    builder: kbdSection,
  ),
  const GalleryEntry(
    name: 'Badge',
    group: GalleryGroup.core,
    source: '$_bundle · components/core/Badge.jsx, lines 354–376',
    builder: badgeSection,
  ),
  const GalleryEntry(
    name: 'Banner',
    group: GalleryGroup.feedback,
    source: '$_bundle · components/feedback/Banner.jsx, lines 822–862',
    builder: bannerSection,
  ),
  const GalleryEntry(
    name: 'ProgressBar',
    group: GalleryGroup.feedback,
    source: '$_bundle · components/feedback/ProgressBar.jsx, lines 864–897',
    builder: progressBarSection,
  ),
  const GalleryEntry(
    name: 'Spinner',
    group: GalleryGroup.feedback,
    source: '$_bundle · components/feedback/Spinner.jsx, lines 899–919',
    builder: spinnerSection,
  ),
  const GalleryEntry(
    name: 'TaskProgress',
    group: GalleryGroup.feedback,
    source: '$_bundle · components/feedback/TaskProgress.jsx, lines 921–1011',
    builder: taskProgressSection,
  ),
  const GalleryEntry(
    name: 'Toast',
    group: GalleryGroup.feedback,
    source: '$_bundle · components/feedback/Toast.jsx, lines 1013–1061',
    builder: toastSection,
  ),
  const GalleryEntry(
    name: 'Field',
    group: GalleryGroup.forms,
    source: 'components/forms/forms.css · .fm-field, .fm-input (internal)',
    builder: fieldSection,
  ),
  const GalleryEntry(
    name: 'TextField',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/TextField.jsx, lines 1731–1781',
    builder: textFieldSection,
  ),
  const GalleryEntry(
    name: 'Select',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/Select.jsx, lines 1641–1693',
    builder: selectSection,
  ),
  const GalleryEntry(
    name: 'NumberStepper',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/NumberStepper.jsx, lines 1502–1601',
    builder: numberStepperSection,
  ),
  const GalleryEntry(
    name: 'Checkbox',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/Checkbox.jsx, lines 1185–1228',
    builder: checkboxSection,
  ),
  const GalleryEntry(
    name: 'Radio',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/Radio.jsx, lines 1603–1639',
    builder: radioSection,
  ),
  const GalleryEntry(
    name: 'Switch',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/Switch.jsx, lines 1695–1729',
    builder: switchSection,
  ),
  const GalleryEntry(
    name: 'ColorPicker',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/ColorPicker.jsx, lines 1230–1365',
    builder: colorPickerSection,
  ),
  const GalleryEntry(
    name: 'FontPicker',
    group: GalleryGroup.forms,
    source: '$_bundle · components/forms/FontPicker.jsx, lines 1367–1500',
    builder: fontPickerSection,
  ),
  const GalleryEntry(
    name: 'Popover',
    group: GalleryGroup.forms,
    source: 'components/forms/forms.css · .fm-popover (internal)',
    builder: popoverSection,
  ),
  const GalleryEntry(
    name: 'ModeTabs',
    group: GalleryGroup.navigation,
    source: '$_bundle · components/navigation/ModeTabs.jsx, lines 1783–1862',
    builder: modeTabsSection,
  ),
  const GalleryEntry(
    name: 'FERMAN_MODES',
    flutterClass: 'FermanMode',
    group: GalleryGroup.navigation,
    source:
        '$_bundle · components/navigation/ModeTabs.jsx, lines 1783–1862 · '
        'FmWindow.dc.html, lines 190–191',
    builder: fermanModesSection,
  ),
  const GalleryEntry(
    name: 'SegmentedControl',
    group: GalleryGroup.navigation,
    source:
        '$_bundle · components/navigation/SegmentedControl.jsx, '
        'lines 1864–1922',
    builder: segmentedControlSection,
  ),
  const GalleryEntry(
    name: 'Toolbar',
    group: GalleryGroup.navigation,
    source: '$_bundle · components/navigation/Toolbar.jsx, lines 2161–2214',
    builder: toolbarSection,
  ),
  const GalleryEntry(
    name: 'ToolbarSeparator',
    group: GalleryGroup.navigation,
    source: '$_bundle · components/navigation/Toolbar.jsx, lines 2161–2214',
    builder: toolbarSeparatorSection,
  ),
  const GalleryEntry(
    name: 'ToolbarSpacer',
    group: GalleryGroup.navigation,
    source: '$_bundle · components/navigation/Toolbar.jsx, lines 2161–2214',
    builder: toolbarSpacerSection,
  ),
  const GalleryEntry(
    name: 'ToolbarGroup',
    group: GalleryGroup.navigation,
    source: '$_bundle · components/navigation/Toolbar.jsx, lines 2161–2214',
    builder: toolbarGroupSection,
  ),
  const GalleryEntry(
    name: 'ToolButton',
    group: GalleryGroup.navigation,
    source: '$_bundle · components/navigation/ToolButton.jsx, lines 2110–2159',
    builder: toolButtonSection,
  ),
  const GalleryEntry(
    name: 'CommandPalette',
    group: GalleryGroup.overlays,
    source:
        '$_bundle · components/overlays/CommandPalette.jsx, lines 2358–2495',
    builder: commandPaletteSection,
  ),
  const GalleryEntry(
    name: 'Dialog',
    group: GalleryGroup.overlays,
    source: '$_bundle · components/overlays/Dialog.jsx, lines 2497–2592',
    builder: dialogSection,
  ),
  const GalleryEntry(
    name: 'Menu',
    group: GalleryGroup.overlays,
    source: '$_bundle · components/overlays/Menu.jsx, lines 2594–2684',
    builder: menuSection,
  ),
  const GalleryEntry(
    name: 'Scrim',
    group: GalleryGroup.overlays,
    source: 'components/overlays/overlays.css · .fm-scrim (internal)',
    builder: scrimSection,
  ),
  const GalleryEntry(
    name: 'PanelSection',
    group: GalleryGroup.panels,
    source: '$_bundle · components/panels/PanelSection.jsx, lines 2745–2792',
    builder: panelSectionSection,
  ),
  const GalleryEntry(
    name: 'PageThumbnail',
    group: GalleryGroup.pages,
    source: '$_bundle · components/pages/PageThumbnail.jsx, lines 2686–2743',
    builder: pageThumbnailSection,
  ),
  const GalleryEntry(
    name: 'PageMark',
    group: GalleryGroup.editing,
    source: '$_bundle · components/editing/PageMark.jsx, lines 519–544',
    builder: pageMarkSection,
  ),
  const GalleryEntry(
    name: 'SearchReplaceBar',
    group: GalleryGroup.editing,
    source: '$_bundle · components/editing/SearchReplaceBar.jsx, lines 546–668',
    builder: searchReplaceBarSection,
  ),
  const GalleryEntry(
    name: 'TextEditBox',
    group: GalleryGroup.editing,
    source: '$_bundle · components/editing/TextEditBox.jsx, lines 670–715',
    builder: textEditBoxSection,
  ),
  const GalleryEntry(
    name: 'TextCaret',
    group: GalleryGroup.editing,
    source: '$_bundle · components/editing/TextEditBox.jsx, lines 670–715',
    builder: textCaretSection,
  ),
  const GalleryEntry(
    name: 'AnnotationTools',
    group: GalleryGroup.annotations,
    source:
        '$_bundle · components/annotations/AnnotationTools.jsx, '
        'lines 2216–2356',
    builder: annotationToolsSection,
  ),
  const GalleryEntry(
    name: 'ANNOTATION_TOOLS',
    flutterClass: 'AnnotationTool',
    group: GalleryGroup.annotations,
    source:
        '$_bundle · components/annotations/AnnotationTools.jsx, '
        'lines 2216–2356 · FmWindow.dc.html, lines 233–237',
    builder: annotationToolsEnumSection,
  ),
  const GalleryEntry(
    name: 'Highlight',
    group: GalleryGroup.annotations,
    source: '$_bundle · components/annotations/Highlight.jsx, lines 11–41',
    builder: highlightSection,
  ),
  const GalleryEntry(
    name: 'StickyNote',
    group: GalleryGroup.annotations,
    source: '$_bundle · components/annotations/StickyNote.jsx, lines 262–352',
    builder: stickyNoteSection,
  ),
  const GalleryEntry(
    name: 'Stamp',
    group: GalleryGroup.annotations,
    source: '$_bundle · components/annotations/Stamp.jsx, lines 43–68',
    builder: stampSection,
  ),
  const GalleryEntry(
    name: 'PdfFormField',
    group: GalleryGroup.fillSign,
    source: '$_bundle · components/fill-sign/PdfFormField.jsx, lines 1063–1183',
    builder: pdfFormFieldSection,
  ),
  const GalleryEntry(
    name: 'SignaturePad',
    group: GalleryGroup.fillSign,
    source: '$_bundle · components/fill-sign/SignaturePad.jsx, lines 1924–2108',
    builder: signaturePadSection,
  ),
  const GalleryEntry(
    name: 'DropZone',
    group: GalleryGroup.empty,
    source: '$_bundle · components/empty/DropZone.jsx, lines 717–820',
    builder: dropZoneSection,
  ),
  const GalleryEntry(
    name: 'DocumentTab',
    group: GalleryGroup.additions,
    source: 'FmWindow.dc.html, lines 21–28 · DS additions.dc.html, lines 62–65',
    builder: documentTabSection,
  ),
  const GalleryEntry(
    name: 'WindowChrome',
    group: GalleryGroup.additions,
    source: 'FmWindow.dc.html, lines 17–34',
    builder: windowChromeSection,
  ),
  const GalleryEntry(
    name: 'SaveIndicator',
    group: GalleryGroup.additions,
    source: 'FmWindow.dc.html, lines 173–177 · 00 Fixes.dc.html, lines 67–96',
    builder: saveIndicatorSection,
  ),
  const GalleryEntry(
    name: 'DatePicker',
    group: GalleryGroup.additions,
    source: 'DocForm.dc.html, lines 33–37',
    builder: datePickerSection,
  ),
  const GalleryEntry(
    name: 'MentionList',
    group: GalleryGroup.additions,
    source: 'FmComments.dc.html, lines 31–32',
    builder: mentionListSection,
  ),
  const GalleryEntry(
    name: 'CommentCard',
    group: GalleryGroup.additions,
    source: 'FmComments.dc.html, lines 25–35',
    builder: commentCardSection,
  ),
  const GalleryEntry(
    name: 'ThumbnailBadges',
    group: GalleryGroup.additions,
    source:
        '00 Fixes.dc.html, lines 98–114 · DS additions.dc.html, line 60 · '
        'FmSidebar.dc.html, lines 38–39',
    builder: thumbnailBadgesSection,
  ),
  const GalleryEntry(
    name: 'FmNumber',
    group: GalleryGroup.additions,
    source: 'FmNumber.dc.html, lines 16–38 · DS additions.dc.html, line 59',
    builder: fmNumberSection,
  ),
];
