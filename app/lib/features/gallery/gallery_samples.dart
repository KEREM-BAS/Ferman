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
  static const String cancel = 'Cancel';

  /// The danger button of the state sheet.
  static const String apply = 'Apply';

  /// The ghost button of the signature pad.
  static const String clear = 'Clear';

  /// The full-width danger button of the Protect panel.
  static const String applyRedactions = 'Apply redactions';

  /// The icon button of the state sheet.
  static const String rotatePage = 'Rotate page';

  /// The toggled icon button of the state sheet.
  static const String bold = 'Bold';

  /// The text style buttons of the Text panel.
  static const String italic = 'Italic';

  /// The "+N" overflow button of the tab strip.
  static const String moreDocuments = '+3';

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
      'You can read while Ferman finishes. Search, thumbnails and editing '
      'turn on when all 2,400 pages are indexed.';

  /// The success box title.
  static const String bannerSuccessTitle = 'Valid PDF/A-2b';

  /// The success box text.
  static const String bannerSuccess =
      'Fonts embedded, colours defined, no encryption, no scripts.';

  /// The warning box.
  static const String bannerWarning =
      'Typing ‘ğ’ here uses a similar font for that character. To keep one '
      'font, pick an installed font with full Turkish support.';

  /// The danger box title.
  static const String bannerDangerTitle = '2 redactions not applied';

  /// The danger box text.
  static const String bannerDanger =
      'Marked text stays in the file until you apply redactions.';

  /// The neutral box.
  static const String bannerNeutral =
      'Partial fonts include only the characters already in the file.';

  /// The info bar title.
  static const String bannerBarTitle = 'This PDF is a fillable form.';

  /// The info bar text.
  static const String bannerBar =
      '20 fields, 15 required. Tab moves to the next field.';

  /// The warning bar title.
  static const String bannerBarWarningTitle =
      '“Kira sözleşmesi.pdf” changed on disk.';

  /// The warning bar text.
  static const String bannerBarWarning =
      'It was modified at 14:41, probably by iCloud Drive. You have 3 '
      'unsaved edits.';

  /// The warning bar action.
  static const String reload = 'Reload';

  /// The dismiss button.
  static const String dismiss = 'Dismiss';

  // Progress (07 Convert, 11b App).

  /// The progress label.
  static const String recognizingText = 'Recognizing text';

  /// The running task's detail.
  static const String taskRunningDetail =
      'Page 14 of 64 · about 2 minutes left';

  /// The paused task's title.
  static const String taskPausedTitle = 'Arşive hazırla · 42 files';

  /// The paused task's detail.
  static const String taskPausedDetail = 'Paused at file 18';

  /// The finished task's title.
  static const String taskDoneTitle = 'Compressed İmar planı açıklama raporu';

  /// The finished task's detail.
  static const String taskDoneDetail = '24,6 MB → 6,9 MB';

  /// The failed task's title.
  static const String taskErrorTitle = 'Couldn’t convert Tarama_0042.pdf';

  /// The failed task's detail.
  static const String taskErrorDetail = 'The file is cut off after 18 KB.';

  /// The task's Pause button.
  static const String pause = 'Pause';

  /// The task's Resume button.
  static const String resume = 'Resume';

  /// The finished task's action.
  static const String showInFolder = 'Show in folder';

  // Toasts (the UI kit).

  /// The neutral toast.
  static const String toastSavedTitle = 'Saved';

  /// The neutral toast's message.
  static const String toastSavedMessage = 'Kira sözleşmesi.pdf · 2.4 MB';

  /// The success toast.
  static const String toastSignatureTitle = 'Signature added';

  /// The success toast's message.
  static const String toastSignatureMessage =
      'Saved on this device for next time.';

  /// The warning toast.
  static const String toastPageTitle = 'A PDF needs at least one page';

  /// The warning toast's message.
  static const String toastPageMessage =
      'Keep one page or close the file instead.';

  /// The danger toast.
  static const String toastErrorTitle = 'Couldn’t save';

  /// The danger toast's message.
  static const String toastErrorMessage =
      'The disk is full — free some space or save somewhere else.';

  /// The toast with an action.
  static const String toastDeletedTitle = '3 pages deleted';

  // Fields (the state sheet and the UI kit's panels).

  /// The state sheet's page field.
  static const String page = 'Page';

  /// The page field's value.
  static const String pageValue = '12';

  /// The page field's value out of range.
  static const String pageValueError = '52';

  /// The page field's error.
  static const String pageError = 'Enter 1–48.';

  /// The page field's hint.
  static const String pageHint = '48 pages';

  /// A field with a unit.
  static const String spaceAfter = 'Space after';

  /// The field with a unit's value.
  static const String spaceAfterValue = '6';

  /// The line spacing stepper.
  static const String lineSpacing = 'Line spacing';

  /// The checkbox of the Convert panel.
  static const String ocrFirst = 'Recognize text first (OCR)';

  // Colour picker (ColorPicker.jsx).

  /// The colour picker's label.
  static const String color = 'Color';

  /// The no-colour swatch.
  static const String noColor = 'No color';

  /// The document colours heading.
  static const String inThisDocument = 'In this document';

  /// The standard colours heading.
  static const String standardColors = 'Standard';

  /// The hex field label.
  static const String hex = 'Hex';

  /// The hex field's name.
  static const String hexColor = 'Hex color';

  /// The popover's name.
  static const String chooseColor = 'Choose color';

  /// The none option.
  static const String none = 'None';

  // Font picker (FontPicker.jsx, the UI kit's document).

  /// The font picker's label.
  static const String font = 'Font';

  /// The document's fonts and the device's.
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
  static const String onThisDevice = 'On this device';

  /// The search field.
  static const String searchFonts = 'Search fonts';

  /// The list's name.
  static const String fonts = 'Fonts';

  /// The missing font's badge.
  static const String notInstalled = 'Not installed';

  /// The missing-font note.
  static const String garamondMissing =
      'Garamond Premier Pro isn’t installed. Ferman is showing EB Garamond '
      'instead.';

  /// The glyph warning.
  static const String glyphWarning =
      'This font has no ‘ğ’. Ferman will use a similar font for this '
      'character.';

  /// The empty search, for a fixed query (see
  /// [GalleryLabels.fontEmptySearchNote]).
  static const String noFontsMatch = 'No fonts match “Garamond”.';

  // Navigation (the UI kit).

  /// The alignment segments.
  static const String alignLeft = 'Align left';

  /// The alignment segments.
  static const String alignCenter = 'Center';

  /// The alignment segments.
  static const String alignRight = 'Align right';

  /// The alignment segments.
  static const String justify = 'Justify';

  /// The alignment group.
  static const String alignment = 'Alignment';

  /// A toolbar group.
  static const String textStyle = 'Text style';

  /// The flags of an annotation tool.
  static const String colored = 'colored';

  /// The flags of an annotation tool.
  static const String hasMenu = 'hasMenu';

  // Command palette (App.jsx, CommandPalette.jsx).

  /// The palette's field.
  static const String paletteSearch = 'Search commands, pages and text';

  /// The palette's name.
  static const String commandPalette = 'Command palette';

  /// The suggested group.
  static const String suggested = 'Suggested';

  /// The modes group.
  static const String modes = 'Modes';

  /// The file group.
  static const String file = 'File';

  /// A command.
  static const String findAndReplace = 'Find and replace';

  /// A command's keywords.
  static const String findAndReplaceKeywords = 'bul değiştir';

  /// A command.
  static const String addSignature = 'Add signature';

  /// A command's keywords.
  static const String addSignatureKeywords = 'imza';

  /// A command.
  static const String redactText = 'Redact text and images';

  /// A command's keywords.
  static const String redactKeywords = 'karart gizle';

  /// A command's hint: the mode it belongs to.
  static const String hintEdit = 'Edit';

  /// A command's hint.
  static const String hintConvert = 'Convert';

  /// A command's hint.
  static const String hintSign = 'Fill & Sign';

  /// A command's hint.
  static const String hintProtect = 'Protect';

  /// "Go to" and a mode.
  static String goTo(String mode) => 'Go to $mode';

  /// The query that matches nothing.
  static const String paletteNoMatchQuery = 'grafik';

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
  static const String move = 'Move';

  /// The footer hints.
  static const String run = 'Run';

  /// The footer hints.
  static const String close = 'Close';

  /// The Esc key cap.
  static const String esc = 'Esc';

  // Dialogs (01 First run, 08 Protect, 11b App, 06 Organize).

  /// The save dialog.
  static const String saveChangesTitle =
      'Save changes to “Kira sözleşmesi.pdf”?';

  /// The save dialog.
  static const String saveChangesDescription =
      'If you don’t save, your 3 edits from this session will be lost.';

  /// The save dialog.
  static const String dontSave = 'Don’t save';

  /// The disk-full dialog.
  static const String diskFullTitle = 'Couldn’t save “Kira sözleşmesi.pdf”';

  /// The disk-full dialog.
  static const String diskFullDescription =
      'The disk is full: 12 MB free, the file needs about 300 KB plus room to '
      'write safely. Free some space or save somewhere else.';

  /// The disk-full dialog.
  static const String saveAs = 'Save as…';

  /// The redaction dialog.
  static const String applyRedactionsTitle = 'Apply 4 redactions?';

  /// The redaction dialog.
  static const String applyRedactionsDescription =
      'The marked text and the area are removed from the file for good, '
      'including from copy, search and hidden layers. You can’t undo this '
      'after saving.';

  /// The large dialog.
  static const String pageLabelsTitle = 'Page labels';

  /// The large dialog.
  static const String pageLabelsDescription =
      'Choose how pages are numbered in Ferman, in other PDF apps and when '
      'printing.';

  // Menu (OrganizeGrid.jsx).

  /// The menu's name.
  static const String pageMenu = 'Page';

  /// A menu item.
  static const String extractAsNew = 'Extract as new PDF…';

  /// A menu item.
  static const String deletePage = 'Delete page';

  /// A menu item.
  static const String insertFromFile = 'Insert from file…';

  // Panel section (the UI kit's Properties panel).

  /// A section title.
  static const String sectionText = 'Text';

  /// A section title.
  static const String sectionParagraph = 'Paragraph';

  /// A section title.
  static const String sectionFile = 'File';

  /// A row of the File section.
  static const String pages = 'Pages';

  /// A row of the File section.
  static const String pagesValue = '3';

  /// A row of the File section.
  static const String size = 'Size';

  /// A row of the File section.
  static const String sizeValue = '2.4 MB';

  /// The section action.
  static const String resetTextStyle = 'Reset text style';

  // Pages.

  /// "Page" and a number.
  static String pageNumber(int page) => 'Page $page';

  /// A roman page label.
  static const String romanLabel = 'ii';

  /// The marker's tooltip.
  static const String editedSinceOpened = 'Edited since opened';

  /// The badges' tooltips (FmSidebar).
  static const String badgeComments = '2 comments';

  /// The badges' tooltips.
  static const String badgeFields = 'Has form fields';

  /// The badges' tooltips.
  static const String badgeSignature = 'Has a signature';

  /// The badges' tooltips.
  static const String badgeWarnings =
      '1 warning · Madde 6 uses a font without ‘ğ’';

  /// The badge legend (FmSidebar).
  static const String legendTitle = 'Page badges';

  /// The badge legend.
  static const String legendFootnote =
      'Screen readers hear badges in the page name, e.g. “Page 1, edited, 2 '
      'comments, 1 warning”.';

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
  static const String runSelection = 'Kiraya veren: Mert Kaya';

  /// An edited run.
  static const String runEdited = 'her ayın onuncu gününe kadar';

  /// A run with a missing glyph.
  static const String runMissingGlyph = 'ağustos';

  /// The missing character.
  static const String missingChar = 'ğ';

  /// A search match.
  static const String runSearch = 'kira bedeli';

  /// A redacted run.
  static const String runRedact = 'TR12 0006 4000 0011 2345 6789 01';

  /// A highlighted run.
  static const String runHighlight = 'her ayın beşinci gününe kadar';

  /// The edited mark's tooltip.
  static const String edited = 'Edited';

  /// The pending redaction's tooltip.
  static const String markedForRedaction =
      'Marked for redaction. Apply redactions to remove it permanently.';

  /// The applied redaction's tooltip.
  static const String redacted = 'Redacted';

  /// A paragraph of the lease.
  static const String paragraph =
      'Kira süresi 01.11.2026 tarihinde başlar ve bir yıl sürer.';

  /// The caret sample, before the caret.
  static const String caretBefore = 'Kira süresi ';

  /// The caret sample, after the caret.
  static const String caretAfter = '01.11.2026 tarihinde başlar.';

  /// The edit box label: the font and size.
  static String editMeta(String font, String size) => '$font · $size';

  // Search bar (SearchReplaceBar.jsx, App.jsx).

  /// The bar's name.
  static const String findAndReplaceRegion = 'Find and replace';

  /// The find field.
  static const String find = 'Find';

  /// The replace field.
  static const String replaceWith = 'Replace with';

  /// An option.
  static const String matchCase = 'Match case';

  /// An option.
  static const String wholeWord = 'Whole word';

  /// An option.
  static const String regex = 'Regular expression';

  /// The disclosure.
  static const String showReplace = 'Show replace';

  /// The disclosure.
  static const String hideReplace = 'Hide replace';

  /// A button.
  static const String previousMatch = 'Previous match';

  /// A button.
  static const String nextMatch = 'Next match';

  /// A button.
  static const String replaceAll = 'Replace all';

  /// The empty count.
  static const String noResults = 'No results';

  /// "N of M".
  static String count(String current, String total) => '$current of $total';

  /// The query.
  static const String query = 'kira';

  /// The replacement.
  static const String replacement = 'Kira';

  /// The query without matches.
  static const String queryNone = 'depozito2';

  /// The query with the font notice.
  static const String queryNotice = 'ağustos';

  /// The font notice.
  static const String searchNotice =
      '1 match uses a font without ‘ğ’. Ferman will use a similar font for '
      'that character.';

  // Annotations (FmComments, 04 Comment).

  /// A person.
  static const String ayse = 'Ayşe Yılmaz';

  /// A person.
  static const String mert = 'Mert Kaya';

  /// A person.
  static const String deniz = 'Av. Deniz Aksoy';

  /// The people of the mention list.
  static const List<({String initials, String name})> people = [
    (initials: 'AY', name: ayse),
    (initials: 'MK', name: mert),
    (initials: 'DA', name: deniz),
  ];

  /// The mention list heading.
  static const String peopleInDocument = 'People in this document';

  /// The mention list's name.
  static const String mentionSomeone = 'Mention someone';

  /// A note.
  static const String noteTime = '09:58';

  /// A note.
  static const String noteText =
      'Artış oranı TÜFE’ye bağlı kalsın, sabit oran istemiyorum.';

  /// A reply.
  static const String replyTime = '10:40';

  /// A reply.
  static const String replyText = 'Olur, 10’u yazalım.';

  /// The note's name.
  static String noteFrom(String author) => 'Note from $author';

  /// The note's Close button.
  static const String closeNote = 'Close note';

  /// The reply field.
  static const String reply = 'Reply';

  /// The comment card.
  static const String commentTime = '10:12';

  /// The comment card.
  static const String commentQuote = '“her ayın beşinci gününe kadar”';

  /// The comment card.
  static const String commentText =
      'Ödeme günü beşi yerine onu olabilir mi? Maaşım ayın yedisinde yatıyor.';

  /// The comment card's second reply.
  static const String replyTime2 = '11:02';

  /// The comment card's second reply.
  static const String replyText2 =
      '@Mert Kaya maddeyi buna göre güncelliyorum.';

  /// The resolved card.
  static const String resolvedQuote = '“TR12 0006 4000 0011 2345 6789 01”';

  /// The resolved card.
  static const String resolvedText = 'IBAN’ı bankadan teyit ettim.';

  /// The resolved card.
  static const String yesterday = 'Yesterday';

  /// The resolved card.
  static const String resolvedBy = 'Resolved by Mert Kaya · 11:06';

  /// The cards' replies count.
  static const String twoReplies = '2 replies';

  /// The card's name.
  static const String commentLabel =
      'Ayşe Yılmaz, highlight on page 1, 2 replies';

  /// The resolved card's name.
  static const String resolvedLabel =
      'Ayşe Yılmaz, underline on page 1, resolved';

  /// The card's buttons.
  static const String resolve = 'Resolve';

  /// The card's buttons.
  static const String reopen = 'Reopen';

  /// The stamps of 04 Comment, per tone.
  static const Map<String, String> stamps = {
    'seal': 'Confidential',
    'ink': 'Final',
    'green': 'Approved',
    'neutral': 'Draft',
  };

  /// The Turkish stamp, uppercased with Turkish rules ("GİZLİ").
  static const String stampTurkish = 'Gizli';

  /// The stamp with a meta line.
  static const String stampApproved = 'Onaylandı';

  /// The stamp's meta line.
  static const String stampMeta = '13.10.2026 · Av. D. Aksoy';

  // Form fields (05a Fill, DocForm).

  /// The text field.
  static const String idNumber = 'T.C. Kimlik No';

  /// The text field.
  static const String idNumberValue = '41239876510';

  /// The text field.
  static const String idNumberShort = '4123987651';

  /// The text field.
  static const String idNumberError = 'Enter all 11 digits.';

  /// The multiline field.
  static const String notes = 'Açıklama';

  /// The multiline field.
  static const String notesValue = 'Teslim tutanağı imzadan önce eklensin.';

  /// The date field.
  static const String date = 'Tarih';

  /// The date field.
  static const String dateValue = '01.11.2026';

  /// The date field.
  static const String dateInvalid = '31.02.2026';

  /// The date field.
  static const String dateError = 'February has 28 days in 2026.';

  /// The dropdown.
  static const String province = 'İl';

  /// The dropdown.
  static const String choose = 'Seçiniz';

  /// The dropdown.
  static const List<String> provinces = ['Ankara', 'İstanbul', 'İzmir'];

  /// The dropdown.
  static const String provinceError = 'Choose a province.';

  /// The multiline field, checkboxes and radios.
  static const String notesError = 'Fill in this field.';

  /// The signature field.
  static const String signature = 'İmza';

  /// The signature field.
  static const String signHere = 'Sign here';

  /// The signature field.
  static const String signatureError = 'Sign before finishing.';

  // Signature pad (SignaturePad.jsx).

  /// The pad's texts.
  static const String signatureMethod = 'Signature method';

  /// The pad's texts.
  static const String draw = 'Draw';

  /// The pad's texts.
  static const String type = 'Type';

  /// The pad's texts.
  static const String image = 'Image';

  /// The pad's texts.
  static const String drawingArea =
      'Signature drawing area. Draw with a mouse, trackpad, pen or finger.';

  /// The pad's texts.
  static const String typeYourName = 'Type your name';

  /// The pad's texts.
  static const String yourName = 'Your name';

  /// The pad's texts.
  static const String signAboveLine = 'Sign above the line';

  /// The pad's texts.
  static const String typeAboveLine = 'Type your name above the line';

  /// The pad's texts.
  static const String imageHint =
      'Drop a photo or scan of your signature. Ferman removes the background.';

  /// The pad's texts.
  static const String chooseImage = 'Choose image…';

  /// The pad's texts.
  static const String inkColor = 'Ink color';

  /// The pad's texts.
  static const String saveOnDevice = 'Save on this device';

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
  static const String releaseToOpen = 'Release to open';

  /// The over state.
  static const String opensOnDevice = 'Ferman opens the file on this device.';

  /// The error state.
  static const String notAPdf = 'That file isn’t a PDF';

  /// The error state.
  static const String notAPdfSubtitle =
      'Ferman opens PDF files. To edit a Word or image file, convert it '
      'first.';

  /// The recent files heading.
  static const String recent = 'Recent';

  /// Recent files.
  static const List<(String, String)> recentFiles = [
    ('Kira sözleşmesi.pdf', 'Yesterday · 2.4 MB'),
    ('e-Arşiv fatura 4187.pdf', '13.10.2026 · 180 KB'),
  ];

  // Additions (FmWindow, 00 Fixes, DocForm, FmNumber).

  /// The documents of the tab strip.
  static const String docLease = 'Kira sözleşmesi.pdf';

  /// The documents of the tab strip.
  static const String docInvoice = 'e-Arşiv fatura 4187.pdf';

  /// The documents of the tab strip.
  static const String docStatement = 'Hesap ekstresi Eylül 2026.pdf';

  /// The documents of the tab strip.
  static const String docPlan = 'İmar planı açıklama raporu.pdf';

  /// The documents of the tab strip.
  static const String docPayroll = 'Maaş bordrosu Eylül 2026.pdf';

  /// The documents of the tab strip.
  static const String docRepaired = 'Tarama_0042.pdf';

  /// When the document was saved: the status bar's "14:32".
  static final DateTime savedAt = DateTime(2026, 10, 13, 14, 32);

  /// The month the date picker shows.
  static final DateTime dateMonth = DateTime(2026, 11);

  /// The day the date picker has selected: the lease's start, the first
  /// of the month.
  static final DateTime dateValueDay = DateTime(2026, 11);

  /// The date picker's name.
  static const String chooseDate = 'Choose a date';

  /// The date picker's buttons.
  static const String previousMonth = 'Previous month';

  /// The date picker's buttons.
  static const String nextMonth = 'Next month';

  /// The date picker's buttons.
  static const String today = 'Today';

  /// The date picker's note.
  static const String dateFormatNote = 'Format DD.MM.YYYY · from the form';

  /// The FmNumber error.
  static const String fmNumberError = 'Enter 4–96 pt.';

  /// The FmNumber card's German sample.
  static const String deutsch = 'Deutsch';
}
