// SAMPLE DATA FOR THE COMPONENT GALLERY (`/debug/gallery`), A DEBUG-ONLY
// DEVELOPER TOOL THAT IS NOT SHIPPED UI.
//
// This is the one file of the gallery that holds literal strings: the
// gallery's own labels (control captions, the spec's variant and state
// names) and the components' sample copy, taken from the design's own
// sample data (the UI kit in `_ds_bundle.js`, the boards and the building
// blocks: the lease "Kira sözleşmesi.pdf", its people and its comments).
// Copy that a real screen shows and that has an ARB key comes from
// AppLocalizations in the gallery's sections instead, so the language
// switch changes it; nothing here is translated.
import 'package:flutter/widgets.dart';

/// The names of the spec's states, props and values that the gallery's
/// captions show (`states`, `props` and `variants` in
/// `component_spec.json`), so captions read as the spec does: a caption
/// is a value's `name`. `default` is [GalleryLabels.standard].
enum SpecName {
  /// `accent`.
  accent,

  /// `action`.
  action,

  /// `actions`.
  actions,

  /// `active`.
  active,

  /// `areaFocusVisible`.
  areaFocusVisible,

  /// `arrowDisabled`.
  arrowDisabled,

  /// `badge`.
  badge,

  /// `badges`.
  badges,

  /// `blinking`.
  blinking,

  /// `captionHover`.
  captionHover,

  /// `collapsible`.
  collapsible,

  /// `color`.
  color,

  /// `colorChecked`.
  colorChecked,

  /// `colorFocusVisible`.
  colorFocusVisible,

  /// `colorHover`.
  colorHover,

  /// `colorsDisabled`.
  colorsDisabled,

  /// `colorsDisabledWithReason`.
  colorsDisabledWithReason,

  /// `composing`.
  composing,

  /// `description`.
  description,

  /// `determinate`.
  determinate,

  /// `dot`.
  dot,

  /// `drawing`.
  drawing,

  /// `dropAfter`.
  dropAfter,

  /// `dropBefore`.
  dropBefore,

  /// `edited`.
  edited,

  /// `empty`.
  empty,

  /// `emptyDraw`.
  emptyDraw,

  /// `emptySearch`.
  emptySearch,

  /// `findOnly`.
  findOnly,

  /// `flipRtl`.
  flipRtl,

  /// `fontSize`.
  fontSize,

  /// `fullWidth`.
  fullWidth,

  /// `glyphWarning`.
  glyphWarning,

  /// `group`.
  group,

  /// `headButtonHover`.
  headButtonHover,

  /// `icon`.
  icon,

  /// `iconEnd`.
  iconEnd,

  /// `iconLg`.
  iconLg,

  /// `iconMd`.
  iconMd,

  /// `iconOnly`.
  iconOnly,

  /// `iconSm`.
  iconSm,

  /// `idle`.
  idle,

  /// `inertOutsideEdit`.
  inertOutsideEdit,

  /// `inkChecked`.
  inkChecked,

  /// `kind`.
  kind,

  /// `label`.
  label,

  /// `layout`.
  layout,

  /// `legendOpen`.
  legendOpen,

  /// `locale`.
  locale,

  /// `locked`.
  locked,

  /// `marker`.
  marker,

  /// `maximized`.
  maximized,

  /// `meta`.
  meta,

  /// `metaBelow`.
  metaBelow,

  /// `metaMargin`.
  metaMargin,

  /// `metaPlacement`.
  metaPlacement,

  /// `metaWarning`.
  metaWarning,

  /// `missing`.
  missing,

  /// `mode`.
  mode,

  /// `neutralChip`.
  neutralChip,

  /// `noResults`.
  noResults,

  /// `none`.
  none,

  /// `notice`.
  notice,

  /// `onAccent`.
  onAccent,

  /// `optionFocusVisible`.
  optionFocusVisible,

  /// `optionHover`.
  optionHover,

  /// `optionOn`.
  optionOn,

  /// `outsideMonth`.
  outsideMonth,

  /// `overflow`.
  overflow,

  /// `pinFocusVisible`.
  pinFocusVisible,

  /// `platform`.
  platform,

  /// `region`.
  region,

  /// `repaired`.
  repaired,

  /// `replaceShown`.
  replaceShown,

  /// `required`.
  required,

  /// `resolved`.
  resolved,

  /// `rotated`.
  rotated,

  /// `rtlMirrored`.
  rtlMirrored,

  /// `showIcons`.
  showIcons,

  /// `showLabels`.
  showLabels,

  /// `side`.
  side,

  /// `signed`.
  signed,

  /// `stacked`.
  stacked,

  /// `suffix`.
  suffix,

  /// `surface`.
  surface,

  /// `swatchHover`.
  swatchHover,

  /// `swatchSelected`.
  swatchSelected,

  /// `toolActive`.
  toolActive,

  /// `toolDisabledWithReason`.
  toolDisabledWithReason,

  /// `top`.
  top,

  /// `type`.
  type,

  /// `typed`.
  typed,

  /// `unsaved`.
  unsaved,

  /// `withMenu`.
  withMenu,

  /// `withSwatch`.
  withSwatch,
}

/// The gallery's own labels: the control bar and the spec's names for
/// variants and states (`stateVocabulary` in `component_spec.json`).
abstract final class GalleryLabels {
  /// The page title.
  static const String title = 'Component gallery';

  /// The line under the title.
  static const String subtitle =
      'Every component of the component spec with its variants, sizes and '
      'states, by group. Debug only; compare with the design system boards.';

  /// The theme control.
  static const String theme = 'Theme';

  /// The density control.
  static const String density = 'Density';

  /// The standard density.
  static const String densityStandard = 'Standard';

  /// The touch density.
  static const String densityTouch = 'Touch';

  /// The motion control.
  static const String motion = 'Motion';

  /// Standard motion.
  static const String motionStandard = 'Standard';

  /// Reduced motion.
  static const String motionReduced = 'Reduced';

  /// The direction control.
  static const String direction = 'Direction';

  /// Left to right.
  static const String directionLtr = 'Left to right';

  /// Right to left.
  static const String directionRtl = 'Right to left';

  /// The language control.
  static const String language = 'Language';

  /// The group filter.
  static const String group = 'Group';

  /// Every group.
  static const String allGroups = 'All groups';

  /// Before the Flutter name of a component whose Dart name differs.
  static const String flutterClass = 'Flutter';

  /// After the count of a group's components.
  static String componentCount(int count) =>
      count == 1 ? '1 component' : '$count components';

  // The spec's state names (`stateVocabulary`) and the other captions.

  /// `default`.
  static const String standard = 'default';

  /// `hover`.
  static const String hover = 'hover';

  /// `pressed`.
  static const String pressed = 'pressed';

  /// `focusVisible`.
  static const String focusVisible = 'focusVisible';

  /// `disabled`.
  static const String disabled = 'disabled';

  /// `disabledWithReason`.
  static const String disabledWithReason = 'disabledWithReason';

  /// `disabledChecked`.
  static const String disabledChecked = 'disabledChecked';

  /// `loading`.
  static const String loading = 'loading';

  /// `toggledOn`.
  static const String toggledOn = 'toggledOn';

  /// `selected`.
  static const String selected = 'selected';

  /// `checked`.
  static const String checked = 'checked';

  /// `indeterminate`.
  static const String indeterminate = 'indeterminate';

  /// `error`.
  static const String error = 'error';

  /// `warning`.
  static const String warning = 'warning';

  /// `open`.
  static const String open = 'open';

  /// `closed`.
  static const String closed = 'closed';

  /// `placeholder`.
  static const String placeholder = 'placeholder';

  /// `readOnly`.
  static const String readOnly = 'readOnly';

  /// `expanded`.
  static const String expanded = 'expanded';

  /// `collapsed`.
  static const String collapsed = 'collapsed';

  /// `hidden`.
  static const String hidden = 'hidden';

  /// `visible`.
  static const String visible = 'visible';

  /// `on`.
  static const String on = 'on';

  /// `off`.
  static const String off = 'off';

  /// A size row.
  static const String size = 'size';

  /// A variant row.
  static const String variant = 'variant';

  /// A tone row.
  static const String tone = 'tone';

  /// A state row.
  static const String state = 'state';

  /// The row of a component's other props.
  static const String props = 'props';

  /// `variant: <value>`, `size: <value>` and the like.
  static String named(String prop, String value) => '$prop: $value';

  /// A caption made of several names.
  static String both(String first, String second) => '$first · $second';

  /// A size in logical pixels.
  static String pixels(double size) => '${size.round()} px';

  /// A note under the forced rows.
  static const String forcedNote =
      'hover, pressed and focusVisible are forced, as the design’s state '
      'sheet forces them with data-fm-force.';

  /// Why the Select's open state is not drawn.
  static const String selectOpenNote =
      'open: Select has no prop that opens its list; click a select to see '
      'it.';

  /// Why the NumberStepper's arrow states are not drawn.
  static const String stepperArrowsNote =
      'arrowHover and arrowPressed follow the pointer on one arrow; no prop '
      'or forced state reaches the arrows alone, so point at an arrow to see '
      'them.';

  /// Why the FontPicker's empty search shows a fixed query.
  static const String fontEmptySearchNote =
      'emptySearch: the gallery cannot type into the search field, so the '
      'sample passes no fonts and the copy for a fixed query.';

  /// Why some samples ignore focus.
  static const String noFocusNote =
      'Samples that take focus on their own (an open FontPicker, a typed '
      'signature, a comment being written) are drawn without focus, so the '
      'gallery does not jump to them.';

  /// How the directional icons are shown.
  static const String rtlNote =
      'rtlMirrored: switch the direction to right to left; the eight '
      'directional icons mirror, the others never do.';

  /// How the FmNumber right-to-left state is shown.
  static const String fmNumberRtlNote =
      'rtl: switch the direction to right to left; the arrows move to the '
      'left and the value lines up on the right.';

  /// How the drag-driven states are shown.
  static const String dropOverNote =
      'over: drawn through the state prop, as a drag of files over the zone '
      'shows it.';

  /// The caption of the WindowChrome sample with every button forced to
  /// hover.
  static const String allHovered = 'captionHover + closeHover (forced)';

  /// The TextCaret note.
  static const String caretNote =
      'blinking: in hard steps; solid under reduced motion.';
}

/// The components' sample copy, from the design's own samples.
abstract final class GallerySamples {
  // Buttons (the "Interactive states" sheet and the UI kit).

  /// The secondary button of the state sheet.
  static const String cancel = '\u2066Cancel\u2069';

  /// The danger button of the state sheet.
  static const String apply = '\u2066Apply\u2069';

  /// The ghost button of the signature pad.
  static const String clear = '\u2066Clear\u2069';

  /// The full-width danger button of the Protect panel.
  static const String applyRedactions = '\u2066Apply redactions\u2069';

  /// The icon button of the state sheet.
  static const String rotatePage = '\u2066Rotate page\u2069';

  /// The toggled icon button of the state sheet.
  static const String bold = '\u2066Bold\u2069';

  /// The text style buttons of the Text panel.
  static const String italic = '\u2066Italic\u2069';

  /// The "+N" overflow button of the tab strip.
  static const String moreDocuments = '\u2066+3\u2069';

  // Badges (the UI kit's panels).

  /// A badge per tone.
  static const Map<String, String> badges = {
    'neutral': 'Embedded',
    'accent': 'Fillable',
    'success': 'Signed',
    'warning': 'Partial',
    'danger': 'Required',
    'edited': 'Edited',
  };

  // Banners (01 First run, 09a Tools, 05a Fill, 11b App, the UI kit).

  /// The info box.
  static const String bannerInfo =
      '\u2066You can read while Ferman finishes. Search, thumbnails and '
      'editing '
      'turn on when all 2,400 pages are indexed.\u2069';

  /// The success box title.
  static const String bannerSuccessTitle = '\u2066Valid PDF/A-2b\u2069';

  /// The success box text.
  static const String bannerSuccess =
      '\u2066Fonts embedded, colours defined, no encryption, no scripts.\u2069';

  /// The warning box.
  static const String bannerWarning =
      '\u2066Typing ‘ğ’ here uses a similar font for that character. To keep '
      'one '
      'font, pick an installed font with full Turkish support.\u2069';

  /// The danger box title.
  static const String bannerDangerTitle =
      '\u20662 redactions not applied\u2069';

  /// The danger box text.
  static const String bannerDanger =
      '\u2066Marked text stays in the file until you apply redactions.\u2069';

  /// The neutral box.
  static const String bannerNeutral =
      '\u2066Partial fonts include only the characters already in the '
      'file.\u2069';

  /// The info bar title.
  static const String bannerBarTitle =
      '\u2066This PDF is a fillable form.\u2069';

  /// The info bar text.
  static const String bannerBar =
      '\u206620 fields, 15 required. Tab moves to the next field.\u2069';

  /// The warning bar title.
  static const String bannerBarWarningTitle =
      '\u2066“Kira sözleşmesi.pdf” changed on disk.\u2069';

  /// The warning bar text.
  static const String bannerBarWarning =
      '\u2066It was modified at 14:41, probably by iCloud Drive. You have 3 '
      'unsaved edits.\u2069';

  /// The warning bar action.
  static const String reload = '\u2066Reload\u2069';

  /// The dismiss button.
  static const String dismiss = '\u2066Dismiss\u2069';

  // Progress (07 Convert, 11b App).

  /// The progress label.
  static const String recognizingText = '\u2066Recognizing text\u2069';

  /// The running task's detail.
  static const String taskRunningDetail =
      '\u2066Page 14 of 64 · about 2 minutes left\u2069';

  /// The paused task's title.
  static const String taskPausedTitle = '\u2066Arşive hazırla · 42 files\u2069';

  /// The paused task's detail.
  static const String taskPausedDetail = '\u2066Paused at file 18\u2069';

  /// The finished task's title.
  static const String taskDoneTitle =
      '\u2066Compressed İmar planı açıklama raporu\u2069';

  /// The finished task's detail.
  static const String taskDoneDetail = '\u206624,6 MB → 6,9 MB\u2069';

  /// The failed task's title.
  static const String taskErrorTitle =
      '\u2066Couldn’t convert Tarama_0042.pdf\u2069';

  /// The failed task's detail.
  static const String taskErrorDetail =
      '\u2066The file is cut off after 18 KB.\u2069';

  /// The task's Pause button.
  static const String pause = '\u2066Pause\u2069';

  /// The task's Resume button.
  static const String resume = '\u2066Resume\u2069';

  /// The finished task's action.
  static const String showInFolder = '\u2066Show in folder\u2069';

  // Toasts (the UI kit).

  /// The neutral toast.
  static const String toastSavedTitle = '\u2066Saved\u2069';

  /// The neutral toast's message.
  static const String toastSavedMessage =
      '\u2066Kira sözleşmesi.pdf · 2.4 MB\u2069';

  /// The success toast.
  static const String toastSignatureTitle = '\u2066Signature added\u2069';

  /// The success toast's message.
  static const String toastSignatureMessage =
      '\u2066Saved on this device for next time.\u2069';

  /// The warning toast.
  static const String toastPageTitle =
      '\u2066A PDF needs at least one page\u2069';

  /// The warning toast's message.
  static const String toastPageMessage =
      '\u2066Keep one page or close the file instead.\u2069';

  /// The danger toast.
  static const String toastErrorTitle = '\u2066Couldn’t save\u2069';

  /// The danger toast's message.
  static const String toastErrorMessage =
      '\u2066The disk is full — free some space or save somewhere else.\u2069';

  /// The toast with an action.
  static const String toastDeletedTitle = '\u20663 pages deleted\u2069';

  // Fields (the state sheet and the UI kit's panels).

  /// The state sheet's page field.
  static const String page = '\u2066Page\u2069';

  /// The page field's value.
  static const String pageValue = '\u206612\u2069';

  /// The page field's value out of range.
  static const String pageValueError = '\u206652\u2069';

  /// The page field's error.
  static const String pageError = '\u2066Enter 1–48.\u2069';

  /// The page field's hint.
  static const String pageHint = '\u206648 pages\u2069';

  /// A field with a unit.
  static const String spaceAfter = '\u2066Space after\u2069';

  /// The field with a unit's value.
  static const String spaceAfterValue = '\u20666\u2069';

  /// The line spacing stepper.
  static const String lineSpacing = '\u2066Line spacing\u2069';

  /// The checkbox of the Convert panel.
  static const String ocrFirst = '\u2066Recognize text first (OCR)\u2069';

  // Colour picker (ColorPicker.jsx).

  /// The colour picker's label.
  static const String color = '\u2066Color\u2069';

  /// The no-colour swatch.
  static const String noColor = '\u2066No color\u2069';

  /// The document colours heading.
  static const String inThisDocument = '\u2066In this document\u2069';

  /// The standard colours heading.
  static const String standardColors = '\u2066Standard\u2069';

  /// The hex field label.
  static const String hex = '\u2066Hex\u2069';

  /// The hex field's name.
  static const String hexColor = '\u2066Hex color\u2069';

  /// The popover's name.
  static const String chooseColor = '\u2066Choose color\u2069';

  /// The none option.
  static const String none = '\u2066None\u2069';

  // Font picker (FontPicker.jsx, the UI kit's document).

  /// The font picker's label.
  static const String font = '\u2066Font\u2069';

  /// The document's fonts and the device's.
  // Font names are font families too: never isolated (B099).
  static const String plexSerif = 'IBM Plex Serif';

  /// The document's missing font.
  static const String garamond = 'Garamond Premier Pro';

  /// What Ferman shows instead of the missing font.
  static const String garamondSubstitute = 'EB Garamond';

  /// A device font.
  static const String plexSans = 'IBM Plex Sans';

  /// A device font.
  static const String georgia = 'Georgia';

  /// A device font.
  static const String timesNewRoman = 'Times New Roman';

  /// The device group heading.
  static const String onThisDevice = '\u2066On this device\u2069';

  /// The search field.
  static const String searchFonts = '\u2066Search fonts\u2069';

  /// The list's name.
  static const String fonts = '\u2066Fonts\u2069';

  /// The missing font's badge.
  static const String notInstalled = '\u2066Not installed\u2069';

  /// The missing-font note.
  static const String garamondMissing =
      '\u2066Garamond Premier Pro isn’t installed. Ferman is showing EB '
      'Garamond '
      'instead.\u2069';

  /// The glyph warning.
  static const String glyphWarning =
      '\u2066This font has no ‘ğ’. Ferman will use a similar font for this '
      'character.\u2069';

  /// The empty search, for a fixed query (see
  /// [GalleryLabels.fontEmptySearchNote]).
  static const String noFontsMatch = '\u2066No fonts match “Garamond”.\u2069';

  // Navigation (the UI kit).

  /// The alignment segments.
  static const String alignLeft = '\u2066Align left\u2069';

  /// The alignment segments.
  static const String alignCenter = '\u2066Center\u2069';

  /// The alignment segments.
  static const String alignRight = '\u2066Align right\u2069';

  /// The alignment segments.
  static const String justify = '\u2066Justify\u2069';

  /// The alignment group.
  static const String alignment = '\u2066Alignment\u2069';

  /// A toolbar group.
  static const String textStyle = '\u2066Text style\u2069';

  /// The flags of an annotation tool.
  static const String colored = '\u2066colored\u2069';

  /// The flags of an annotation tool.
  static const String hasMenu = '\u2066hasMenu\u2069';

  // Command palette (App.jsx, CommandPalette.jsx).

  /// The palette's field.
  static const String paletteSearch =
      '\u2066Search commands, pages and text\u2069';

  /// The palette's name.
  static const String commandPalette = '\u2066Command palette\u2069';

  /// The suggested group.
  static const String suggested = '\u2066Suggested\u2069';

  /// The modes group.
  static const String modes = '\u2066Modes\u2069';

  /// The file group.
  static const String file = '\u2066File\u2069';

  /// A command.
  static const String findAndReplace = '\u2066Find and replace\u2069';

  /// A command's keywords.
  static const String findAndReplaceKeywords = '\u2066bul değiştir\u2069';

  /// A command.
  static const String addSignature = '\u2066Add signature\u2069';

  /// A command's keywords.
  static const String addSignatureKeywords = '\u2066imza\u2069';

  /// A command.
  static const String redactText = '\u2066Redact text and images\u2069';

  /// A command's keywords.
  static const String redactKeywords = '\u2066karart gizle\u2069';

  /// A command's hint: the mode it belongs to.
  static const String hintEdit = '\u2066Edit\u2069';

  /// A command's hint.
  static const String hintConvert = '\u2066Convert\u2069';

  /// A command's hint.
  static const String hintSign = '\u2066Fill & Sign\u2069';

  /// A command's hint.
  static const String hintProtect = '\u2066Protect\u2069';

  /// "Go to" and a mode.
  static String goTo(String mode) => 'Go to $mode';

  /// The query that matches nothing.
  static const String paletteNoMatchQuery = '\u2066grafik\u2069';

  /// The empty list's text.
  static String paletteEmpty(String query) =>
      'No commands match “$query”. Press Enter to search the document '
      'instead.';

  /// The footer's key caps for moving.
  static const List<String> moveKeys = ['↑', '↓'];

  /// The footer's key caps for running, and the next match's.
  static const List<String> runKeys = ['↵'];

  /// The previous match's key caps.
  static const List<String> previousMatchKeys = ['⇧', '↵'];

  /// The footer hints.
  static const String move = '\u2066Move\u2069';

  /// The footer hints.
  static const String run = '\u2066Run\u2069';

  /// The footer hints.
  static const String close = '\u2066Close\u2069';

  /// The Esc key cap.
  static const String esc = '\u2066Esc\u2069';

  // Dialogs (01 First run, 08 Protect, 11b App, 06 Organize).

  /// The save dialog.
  static const String saveChangesTitle =
      '\u2066Save changes to “Kira sözleşmesi.pdf”?\u2069';

  /// The save dialog.
  static const String saveChangesDescription =
      '\u2066If you don’t save, your 3 edits from this session will be '
      'lost.\u2069';

  /// The save dialog.
  static const String dontSave = '\u2066Don’t save\u2069';

  /// The disk-full dialog.
  static const String diskFullTitle =
      '\u2066Couldn’t save “Kira sözleşmesi.pdf”\u2069';

  /// The disk-full dialog.
  static const String diskFullDescription =
      '\u2066The disk is full: 12 MB free, the file needs about 300 KB plus '
      'room to '
      'write safely. Free some space or save somewhere else.\u2069';

  /// The disk-full dialog.
  static const String saveAs = '\u2066Save as…\u2069';

  /// The redaction dialog.
  static const String applyRedactionsTitle = '\u2066Apply 4 redactions?\u2069';

  /// The redaction dialog.
  static const String applyRedactionsDescription =
      '\u2066The marked text and the area are removed from the file for good, '
      'including from copy, search and hidden layers. You can’t undo this '
      'after saving.\u2069';

  /// The large dialog.
  static const String pageLabelsTitle = '\u2066Page labels\u2069';

  /// The large dialog.
  static const String pageLabelsDescription =
      '\u2066Choose how pages are numbered in Ferman, in other PDF apps and '
      'when '
      'printing.\u2069';

  // Menu (OrganizeGrid.jsx).

  /// The menu's name.
  static const String pageMenu = '\u2066Page\u2069';

  /// A menu item.
  static const String extractAsNew = '\u2066Extract as new PDF…\u2069';

  /// A menu item.
  static const String deletePage = '\u2066Delete page\u2069';

  /// A menu item.
  static const String insertFromFile = '\u2066Insert from file…\u2069';

  // Panel section (the UI kit's Properties panel).

  /// A section title.
  static const String sectionText = '\u2066Text\u2069';

  /// A section title.
  static const String sectionParagraph = '\u2066Paragraph\u2069';

  /// A section title.
  static const String sectionFile = '\u2066File\u2069';

  /// A row of the File section.
  static const String pages = '\u2066Pages\u2069';

  /// A row of the File section.
  static const String pagesValue = '\u20663\u2069';

  /// A row of the File section.
  static const String size = '\u2066Size\u2069';

  /// A row of the File section.
  static const String sizeValue = '\u20662.4 MB\u2069';

  /// The section action.
  static const String resetTextStyle = '\u2066Reset text style\u2069';

  // Pages.

  /// "Page" and a number.
  static String pageNumber(int page) => 'Page $page';

  /// A roman page label.
  static const String romanLabel = '\u2066ii\u2069';

  /// The marker's tooltip.
  static const String editedSinceOpened = '\u2066Edited since opened\u2069';

  /// The badges' tooltips (FmSidebar).
  static const String badgeComments = '\u20662 comments\u2069';

  /// The badges' tooltips.
  static const String badgeFields = '\u2066Has form fields\u2069';

  /// The badges' tooltips.
  static const String badgeSignature = '\u2066Has a signature\u2069';

  /// The badges' tooltips.
  static const String badgeWarnings =
      '\u20661 warning · Madde 6 uses a font without ‘ğ’\u2069';

  /// The badge legend (FmSidebar).
  static const String legendTitle = '\u2066Page badges\u2069';

  /// The badge legend.
  static const String legendFootnote =
      '\u2066Screen readers hear badges in the page name, e.g. “Page 1, '
      'edited, 2 '
      'comments, 1 warning”.\u2069';

  /// The badge legend's rows.
  static const List<(String, String)> legendEntries = [
    ('Edited', 'changed since you opened it'),
    ('Comments', 'notes or markup on the page'),
    ('Form fields', 'fields you can fill in'),
    ('Signature', 'signed or has a signature field'),
    ('Warnings', 'missing glyphs, overflow, broken links'),
  ];

  // Page text (the UI kit's lease).

  /// A selected run.
  static const String runSelection = '\u2066Kiraya veren: Mert Kaya\u2069';

  /// An edited run.
  static const String runEdited = '\u2066her ayın onuncu gününe kadar\u2069';

  /// A run with a missing glyph.
  static const String runMissingGlyph = '\u2066ağustos\u2069';

  /// The missing character.
  static const String missingChar = '\u2066ğ\u2069';

  /// A search match.
  static const String runSearch = '\u2066kira bedeli\u2069';

  /// A redacted run.
  static const String runRedact =
      '\u2066TR12 0006 4000 0011 2345 6789 01\u2069';

  /// A highlighted run.
  static const String runHighlight =
      '\u2066her ayın beşinci gününe kadar\u2069';

  /// The edited mark's tooltip.
  static const String edited = '\u2066Edited\u2069';

  /// The pending redaction's tooltip.
  static const String markedForRedaction =
      '\u2066Marked for redaction. Apply redactions to remove it '
      'permanently.\u2069';

  /// The applied redaction's tooltip.
  static const String redacted = '\u2066Redacted\u2069';

  /// A paragraph of the lease.
  static const String paragraph =
      '\u2066Kira süresi 01.11.2026 tarihinde başlar ve bir yıl sürer.\u2069';

  /// The caret sample, before the caret.
  static const String caretBefore = '\u2066Kira süresi \u2069';

  /// The caret sample, after the caret.
  static const String caretAfter = '\u206601.11.2026 tarihinde başlar.\u2069';

  /// The edit box label: the font and size.
  static String editMeta(String font, String size) => '$font · $size';

  // Search bar (SearchReplaceBar.jsx, App.jsx).

  /// The bar's name.
  static const String findAndReplaceRegion = '\u2066Find and replace\u2069';

  /// The find field.
  static const String find = '\u2066Find\u2069';

  /// The replace field.
  static const String replaceWith = '\u2066Replace with\u2069';

  /// An option.
  static const String matchCase = '\u2066Match case\u2069';

  /// An option.
  static const String wholeWord = '\u2066Whole word\u2069';

  /// An option.
  static const String regex = '\u2066Regular expression\u2069';

  /// The disclosure.
  static const String showReplace = '\u2066Show replace\u2069';

  /// The disclosure.
  static const String hideReplace = '\u2066Hide replace\u2069';

  /// A button.
  static const String previousMatch = '\u2066Previous match\u2069';

  /// A button.
  static const String nextMatch = '\u2066Next match\u2069';

  /// A button.
  static const String replaceAll = '\u2066Replace all\u2069';

  /// The empty count.
  static const String noResults = '\u2066No results\u2069';

  /// "N of M".
  static String count(String current, String total) => '$current of $total';

  /// The query.
  static const String query = '\u2066kira\u2069';

  /// The replacement.
  static const String replacement = '\u2066Kira\u2069';

  /// The query without matches.
  static const String queryNone = '\u2066depozito2\u2069';

  /// The query with the font notice.
  static const String queryNotice = '\u2066ağustos\u2069';

  /// The font notice.
  static const String searchNotice =
      '\u20661 match uses a font without ‘ğ’. Ferman will use a similar font '
      'for '
      'that character.\u2069';

  // Annotations (FmComments, 04 Comment).

  /// A person.
  static const String ayse = '\u2066Ayşe Yılmaz\u2069';

  /// A person.
  static const String mert = '\u2066Mert Kaya\u2069';

  /// A person.
  static const String deniz = '\u2066Av. Deniz Aksoy\u2069';

  /// The people of the mention list.
  static const List<({String initials, String name})> people = [
    (initials: 'AY', name: ayse),
    (initials: 'MK', name: mert),
    (initials: 'DA', name: deniz),
  ];

  /// The mention list heading.
  static const String peopleInDocument = '\u2066People in this document\u2069';

  /// The mention list's name.
  static const String mentionSomeone = '\u2066Mention someone\u2069';

  /// A note.
  static const String noteTime = '\u206609:58\u2069';

  /// A note.
  static const String noteText =
      '\u2066Artış oranı TÜFE’ye bağlı kalsın, sabit oran istemiyorum.\u2069';

  /// A reply.
  static const String replyTime = '\u206610:40\u2069';

  /// A reply.
  static const String replyText = '\u2066Olur, 10’u yazalım.\u2069';

  /// The note's name.
  static String noteFrom(String author) => 'Note from $author';

  /// The note's Close button.
  static const String closeNote = '\u2066Close note\u2069';

  /// The reply field.
  static const String reply = '\u2066Reply\u2069';

  /// The comment card.
  static const String commentTime = '\u206610:12\u2069';

  /// The comment card.
  static const String commentQuote =
      '\u2066“her ayın beşinci gününe kadar”\u2069';

  /// The comment card.
  static const String commentText =
      '\u2066Ödeme günü beşi yerine onu olabilir mi? Maaşım ayın yedisinde '
      'yatıyor.\u2069';

  /// The comment card's second reply.
  static const String replyTime2 = '\u206611:02\u2069';

  /// The comment card's second reply.
  static const String replyText2 =
      '\u2066@Mert Kaya maddeyi buna göre güncelliyorum.\u2069';

  /// The resolved card.
  static const String resolvedQuote =
      '\u2066“TR12 0006 4000 0011 2345 6789 01”\u2069';

  /// The resolved card.
  static const String resolvedText = '\u2066IBAN’ı bankadan teyit ettim.\u2069';

  /// The resolved card.
  static const String yesterday = '\u2066Yesterday\u2069';

  /// The resolved card.
  static const String resolvedBy = '\u2066Resolved by Mert Kaya · 11:06\u2069';

  /// The cards' replies count.
  static const String twoReplies = '\u20662 replies\u2069';

  /// The card's name.
  static const String commentLabel =
      '\u2066Ayşe Yılmaz, highlight on page 1, 2 replies\u2069';

  /// The resolved card's name.
  static const String resolvedLabel =
      '\u2066Ayşe Yılmaz, underline on page 1, resolved\u2069';

  /// The card's buttons.
  static const String resolve = '\u2066Resolve\u2069';

  /// The card's buttons.
  static const String reopen = '\u2066Reopen\u2069';

  /// The stamps of 04 Comment, per tone.
  static const Map<String, String> stamps = {
    'seal': 'Confidential',
    'ink': 'Final',
    'green': 'Approved',
    'neutral': 'Draft',
  };

  /// The Turkish stamp, uppercased with Turkish rules ("GİZLİ").
  static const String stampTurkish = '\u2066Gizli\u2069';

  /// The stamp with a meta line.
  static const String stampApproved = '\u2066Onaylandı\u2069';

  /// The stamp's meta line.
  static const String stampMeta = '\u206613.10.2026 · Av. D. Aksoy\u2069';

  // Form fields (05a Fill, DocForm).

  /// The text field.
  static const String idNumber = '\u2066T.C. Kimlik No\u2069';

  /// The text field.
  static const String idNumberValue = '\u206641239876510\u2069';

  /// The text field.
  static const String idNumberShort = '\u20664123987651\u2069';

  /// The text field.
  static const String idNumberError = '\u2066Enter all 11 digits.\u2069';

  /// The multiline field.
  static const String notes = '\u2066Açıklama\u2069';

  /// The multiline field.
  static const String notesValue =
      '\u2066Teslim tutanağı imzadan önce eklensin.\u2069';

  /// The date field.
  static const String date = '\u2066Tarih\u2069';

  /// The date field.
  static const String dateValue = '\u206601.11.2026\u2069';

  /// The date field.
  static const String dateInvalid = '\u206631.02.2026\u2069';

  /// The date field.
  static const String dateError = '\u2066February has 28 days in 2026.\u2069';

  /// The dropdown.
  static const String province = '\u2066İl\u2069';

  /// The dropdown.
  static const String choose = '\u2066Seçiniz\u2069';

  /// The dropdown.
  static const List<String> provinces = ['Ankara', 'İstanbul', 'İzmir'];

  /// The dropdown.
  static const String provinceError = '\u2066Choose a province.\u2069';

  /// The multiline field, checkboxes and radios.
  static const String notesError = '\u2066Fill in this field.\u2069';

  /// The signature field.
  static const String signature = '\u2066İmza\u2069';

  /// The signature field.
  static const String signHere = '\u2066Sign here\u2069';

  /// The signature field.
  static const String signatureError = '\u2066Sign before finishing.\u2069';

  // Signature pad (SignaturePad.jsx).

  /// The pad's texts.
  static const String signatureMethod = '\u2066Signature method\u2069';

  /// The pad's texts.
  static const String draw = '\u2066Draw\u2069';

  /// The pad's texts.
  static const String type = '\u2066Type\u2069';

  /// The pad's texts.
  static const String image = '\u2066Image\u2069';

  /// The pad's texts.
  static const String drawingArea =
      '\u2066Signature drawing area. Draw with a mouse, trackpad, pen or '
      'finger.\u2069';

  /// The pad's texts.
  static const String typeYourName = '\u2066Type your name\u2069';

  /// The pad's texts.
  static const String yourName = '\u2066Your name\u2069';

  /// The pad's texts.
  static const String signAboveLine = '\u2066Sign above the line\u2069';

  /// The pad's texts.
  static const String typeAboveLine =
      '\u2066Type your name above the line\u2069';

  /// The pad's texts.
  static const String imageHint =
      '\u2066Drop a photo or scan of your signature. Ferman removes the '
      'background.\u2069';

  /// The pad's texts.
  static const String chooseImage = '\u2066Choose image…\u2069';

  /// The pad's texts.
  static const String inkColor = '\u2066Ink color\u2069';

  /// The pad's texts.
  static const String saveOnDevice = '\u2066Save on this device\u2069';

  /// A drawn signature: one stroke in the pad's 188 px area.
  static const List<List<Offset>> signatureStrokes = [
    [
      Offset(40, 120),
      Offset(52, 92),
      Offset(64, 78),
      Offset(72, 96),
      Offset(70, 128),
      Offset(84, 104),
      Offset(100, 90),
      Offset(108, 112),
      Offset(120, 100),
      Offset(136, 96),
      Offset(150, 118),
      Offset(168, 92),
      Offset(186, 104),
      Offset(204, 98),
      Offset(226, 110),
    ],
    [Offset(96, 70), Offset(112, 66)],
  ];

  // Drop zone (DropZone.jsx).

  /// The over state.
  static const String releaseToOpen = '\u2066Release to open\u2069';

  /// The over state.
  static const String opensOnDevice =
      '\u2066Ferman opens the file on this device.\u2069';

  /// The error state.
  static const String notAPdf = '\u2066That file isn’t a PDF\u2069';

  /// The error state.
  static const String notAPdfSubtitle =
      '\u2066Ferman opens PDF files. To edit a Word or image file, convert it '
      'first.\u2069';

  /// The recent files heading.
  static const String recent = '\u2066Recent\u2069';

  /// Recent files.
  static const List<(String, String)> recentFiles = [
    ('Kira sözleşmesi.pdf', 'Yesterday · 2.4 MB'),
    ('e-Arşiv fatura 4187.pdf', '13.10.2026 · 180 KB'),
  ];

  // Additions (FmWindow, 00 Fixes, DocForm, FmNumber).

  /// The documents of the tab strip.
  static const String docLease = '\u2066Kira sözleşmesi.pdf\u2069';

  /// The documents of the tab strip.
  static const String docInvoice = '\u2066e-Arşiv fatura 4187.pdf\u2069';

  /// The documents of the tab strip.
  static const String docStatement =
      '\u2066Hesap ekstresi Eylül 2026.pdf\u2069';

  /// The documents of the tab strip.
  static const String docPlan = '\u2066İmar planı açıklama raporu.pdf\u2069';

  /// The documents of the tab strip.
  static const String docPayroll = '\u2066Maaş bordrosu Eylül 2026.pdf\u2069';

  /// The documents of the tab strip.
  static const String docRepaired = '\u2066Tarama_0042.pdf\u2069';

  /// When the document was saved: the status bar's "14:32".
  static final DateTime savedAt = DateTime(2026, 10, 13, 14, 32);

  /// The month the date picker shows.
  static final DateTime dateMonth = DateTime(2026, 11);

  /// The day the date picker has selected: the lease's start, the first
  /// of the month.
  static final DateTime dateValueDay = DateTime(2026, 11);

  /// The date picker's name.
  static const String chooseDate = '\u2066Choose a date\u2069';

  /// The date picker's buttons.
  static const String previousMonth = '\u2066Previous month\u2069';

  /// The date picker's buttons.
  static const String nextMonth = '\u2066Next month\u2069';

  /// The date picker's buttons.
  static const String today = '\u2066Today\u2069';

  /// The date picker's note.
  static const String dateFormatNote =
      '\u2066Format DD.MM.YYYY · from the form\u2069';

  /// The FmNumber error.
  static const String fmNumberError = '\u2066Enter 4–96 pt.\u2069';

  /// The FmNumber card's German sample.
  static const String deutsch = '\u2066Deutsch\u2069';
}
