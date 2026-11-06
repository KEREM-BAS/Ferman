import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// Title bar: tooltip and screen-reader name of the house button that shows the start screen, and the name of the home tab when the start screen shows (FmWindow t.home).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellHome;

  /// Title bar: screen-reader name of the strip of document tabs (FmWindow t.docs). "Open" is an adjective: the documents that are open.
  ///
  /// In en, this message translates to:
  /// **'Open documents'**
  String get shellOpenDocuments;

  /// Title bar: tooltip and screen-reader name of the "+" button after the document tabs, which opens a file (FmWindow t.open).
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get shellOpenFile;

  /// Title bar: tooltip and screen-reader name of the small x button on the active document tab (FmWindow t.closeDoc). Closes the document, not the window.
  ///
  /// In en, this message translates to:
  /// **'Close document'**
  String get shellCloseDocument;

  /// Tooltip of the dot on a document tab, read after the file name by screen readers, and the status-bar save state of a document with unsaved changes (FmWindow t.unsaved).
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get shellUnsavedChanges;

  /// Screen-reader label of the small spinner on a document tab while the file is still opening (FmWindow Spinner label).
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get shellOpening;

  /// Title bar: screen-reader name of the "+N" button that lists the open documents whose tabs do not fit (FmWindow t.more). {count} is the number of those documents, already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String shellMoreDocuments(String count);

  /// Title bar: the visible label of the button that lists the open documents whose tabs do not fit, a plus sign and their number (FmWindow overflowLabel, for example "+3"). {count} is already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String shellMoreDocumentsBadge(String count);

  /// Title bar: label of the Search button, which opens the command palette (FmWindow t.search). A verb.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shellSearch;

  /// Title bar: tooltip and screen-reader name of the gear button that opens Settings (FmWindow t.settings).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettings;

  /// Mode bar: screen-reader name of the row of mode tabs (FmWindow t.modeLabel).
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get shellModeLabel;

  /// Mode tab: reading, zoom and page layout (FmWindow modes[0]). A proper name of the mode; keep it short.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get shellModeView;

  /// Mode tab: editing text and content (FmWindow modes[1]); also the title of the right panel in this mode. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get shellModeEdit;

  /// Mode tab: comments and annotations (FmWindow modes[2]). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get shellModeComment;

  /// Mode tab: filling forms and signing (FmWindow modes[3]). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Fill & Sign'**
  String get shellModeSign;

  /// Mode tab: organizing pages (FmWindow modes[4]). The Turkish design uses "Sayfalar" so it cannot be confused with Düzenle (Edit).
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get shellModeOrganize;

  /// Mode tab: converting to and from other formats (FmWindow modes[5]). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get shellModeConvert;

  /// Mode tab: passwords and redaction (FmWindow modes[6]). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Protect'**
  String get shellModeProtect;

  /// Mode tab: compress, compare and the other tools (FmWindow modes[7]); also the screen-reader name of that mode's tool row. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get shellModeTools;

  /// Mode bar: tooltip and screen-reader name of the button that shows or hides the sidebar on the start side (FmWindow t.sidebar).
  ///
  /// In en, this message translates to:
  /// **'Show or hide sidebar'**
  String get shellToggleSidebar;

  /// Mode bar: tooltip and screen-reader name of the button that shows or hides the right panel (FmWindow t.panel).
  ///
  /// In en, this message translates to:
  /// **'Show or hide panel'**
  String get shellTogglePanel;

  /// Name of the AI assistant: the mode-bar button (shown only when AI is turned on) and the last tool of the Tools row (FmWindow t.ai).
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get shellAiAssistant;

  /// Mode bar: label of the primary Save button (FmWindow t.save). A verb.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shellSave;

  /// Tooltip of the disabled Save button when the document has no unsaved changes (FmWindow t.saveTipOff).
  ///
  /// In en, this message translates to:
  /// **'No changes to save'**
  String get shellNoChangesToSave;

  /// Screen-reader name of the View mode's tool row (FmWindow Toolbar label).
  ///
  /// In en, this message translates to:
  /// **'View tools'**
  String get shellViewTools;

  /// Tool button in the View and Comment tool rows: the pointer that selects text and objects (FmWindow, mouse-pointer icon). A verb.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get shellToolSelect;

  /// View tool row: the hand tool that drags the page around (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Hand'**
  String get shellToolHand;

  /// View tool row: the tool that zooms to a rectangle the user drags (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Marquee zoom'**
  String get shellToolMarqueeZoom;

  /// Tooltip and screen-reader name of the zoom-out buttons in the View tool row and the status bar (FmWindow t.zoomOut).
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get shellZoomOut;

  /// Tooltip and screen-reader name of the zoom-in buttons in the View tool row and the status bar (FmWindow t.zoomIn).
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get shellZoomIn;

  /// View tool row: screen-reader name of the zoom percentage menu (FmWindow aria-label).
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get shellZoom;

  /// View tool row: screen-reader name of the group of three fit buttons (fit width, fit page, actual size) (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get shellFit;

  /// Zoom choice that fits the page width to the window: a fit button and a zoom-menu entry (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get shellFitWidth;

  /// Zoom choice that fits the whole page in the window: a fit button and a zoom-menu entry (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Fit page'**
  String get shellFitPage;

  /// Zoom choice that shows the page at its printed size (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Actual size'**
  String get shellActualSize;

  /// View tool row: screen-reader name of the group of four page-layout buttons (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Page layout'**
  String get shellPageLayout;

  /// Page layout button: one page at a time (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Single page'**
  String get shellLayoutSingle;

  /// Page layout button: pages one under another, scrolling continuously (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Continuous scroll'**
  String get shellLayoutContinuous;

  /// Page layout button: two pages side by side (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Two-page spread'**
  String get shellLayoutTwoPage;

  /// Page layout button: two pages side by side with the cover page on its own, like a book (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Book (cover page alone)'**
  String get shellLayoutBook;

  /// View tool row: shows two views of documents side by side (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Split view'**
  String get shellToolSplitView;

  /// View tool row: reads the document aloud with the system voice (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get shellToolReadAloud;

  /// View tool row: shows the document full screen as a presentation (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get shellToolPresent;

  /// View tool row: switch that shows pages with dark backgrounds for reading at night (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Dark reading mode'**
  String get shellDarkReadingMode;

  /// Screen-reader name of the Edit mode's tool row (FmWindow t.editTools).
  ///
  /// In en, this message translates to:
  /// **'Edit tools'**
  String get shellEditTools;

  /// Edit tool row: the tool that edits existing text in the PDF (FmWindow t.editText).
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get shellToolEditText;

  /// Tool button in the Edit and Fill & Sign tool rows: adds new text on the page (FmWindow t.addText).
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get shellToolAddText;

  /// Edit tool row: adds an image on the page (FmWindow t.addImage).
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get shellToolAddImage;

  /// Edit tool row: adds or edits a link (FmWindow t.link). A noun.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get shellToolLink;

  /// Edit tool row: finds text and replaces it (FmWindow t.findReplace).
  ///
  /// In en, this message translates to:
  /// **'Find & replace'**
  String get shellToolFindReplace;

  /// Edit tool row: menu of watermarks, headers and footers, Bates numbers and page backgrounds (FmWindow t.pageMarks).
  ///
  /// In en, this message translates to:
  /// **'Page marks'**
  String get shellToolPageMarks;

  /// Edit tool row: tooltip and screen-reader name of the undo button (FmWindow t.undo).
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get shellUndo;

  /// Edit tool row: tooltip and screen-reader name of the redo button (FmWindow t.redo).
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get shellRedo;

  /// Edit tool row: tooltip and screen-reader name of the button that shows the list of edits made in this session (FmWindow t.history).
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get shellEditHistory;

  /// Edit tool row: switch that marks the edited text on the page (FmWindow t.markEdited).
  ///
  /// In en, this message translates to:
  /// **'Mark edited text'**
  String get shellMarkEditedText;

  /// Edit tool row: button that opens the list of edits to review, followed by their number (FmWindow t.review).
  ///
  /// In en, this message translates to:
  /// **'Review edits'**
  String get shellReviewEdits;

  /// Screen-reader name of the Comment mode's tool row (AnnotationTools).
  ///
  /// In en, this message translates to:
  /// **'Comment tools'**
  String get shellCommentTools;

  /// Comment tool: highlights text (FmWindow annotTools). A verb.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get shellAnnotationHighlight;

  /// Comment tool: underlines text as a comment mark (FmWindow annotTools). A verb.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get shellAnnotationUnderline;

  /// Comment tool: strikes through text as a comment mark (FmWindow annotTools).
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get shellAnnotationStrikethrough;

  /// Comment tool: adds a sticky note (FmWindow annotTools). A noun.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get shellAnnotationNote;

  /// Comment tool: adds a text box comment on the page (FmWindow annotTools). A noun.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get shellAnnotationText;

  /// Comment tool: adds a text box with a pointer line (FmWindow annotTools). A noun.
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get shellAnnotationCallout;

  /// Comment tool: freehand drawing with a pen (FmWindow annotTools). A verb.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get shellAnnotationDraw;

  /// Comment tool: menu of rectangles, ellipses, lines and arrows (FmWindow annotTools).
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get shellAnnotationShapes;

  /// Comment tool: menu of stamps such as Approved (FmWindow annotTools). A noun.
  ///
  /// In en, this message translates to:
  /// **'Stamp'**
  String get shellAnnotationStamp;

  /// Tool button in the Comment and Tools rows: measures distances and areas on the page (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get shellToolMeasure;

  /// Comment tool row: screen-reader name of the group of annotation colours (AnnotationTools).
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get shellColor;

  /// Annotation colour name, read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get shellColorYellow;

  /// Annotation colour name, read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get shellColorGreen;

  /// Annotation colour name, read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get shellColorBlue;

  /// Annotation colour name, read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get shellColorPink;

  /// Annotation colour name, read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get shellColorOrange;

  /// Annotation colour name, read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get shellColorRed;

  /// Annotation colour name (the ink colour), read by screen readers (design palette).
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get shellColorBlack;

  /// Comment tool row: switch that shows or hides every comment on the pages (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Show comments'**
  String get shellShowComments;

  /// Screen-reader name of the Fill & Sign mode's tool row (FmWindow Toolbar label).
  ///
  /// In en, this message translates to:
  /// **'Fill and sign tools'**
  String get shellFillSignTools;

  /// Fill & Sign tool row: fills in the form fields of the PDF (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Fill fields'**
  String get shellToolFillFields;

  /// Fill & Sign tool row: puts a check mark on the page (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Checkmark'**
  String get shellToolCheckmark;

  /// Fill & Sign tool row: puts a date on the page (FmWindow). A noun.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get shellToolDate;

  /// Fill & Sign tool row: menu that adds a signature (FmWindow; the same word as the Sign tool of the mobile home, FmMHome tools). A verb.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get shellToolSign;

  /// Fill & Sign tool row: adds the signer's initials (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Initials'**
  String get shellToolInitials;

  /// Fill & Sign tool row: signs with a certificate (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Digital signature'**
  String get shellToolDigitalSignature;

  /// Fill & Sign tool row: signs with a Turkish e-imza card (FmWindow). A Turkish product name: keep "e-imza" in every language.
  ///
  /// In en, this message translates to:
  /// **'e-imza'**
  String get shellToolEimza;

  /// Fill & Sign tool row: adds form fields to a PDF (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Prepare form'**
  String get shellToolPrepareForm;

  /// Screen-reader name of the Organize mode's tool row (FmWindow Toolbar label).
  ///
  /// In en, this message translates to:
  /// **'Organize tools'**
  String get shellOrganizeTools;

  /// Organize tool row: menu that inserts blank pages or pages from a file (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get shellToolInsert;

  /// Organize tool row: tooltip and screen-reader name of the button that rotates the selected pages counterclockwise (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get shellToolRotateLeft;

  /// Organize tool row: tooltip and screen-reader name of the button that rotates the selected pages clockwise (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get shellToolRotateRight;

  /// Organize tool row: duplicates the selected pages (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get shellToolDuplicate;

  /// Organize tool row: saves the selected pages as a new PDF (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get shellToolExtract;

  /// Organize tool row: replaces the selected pages with pages from another file (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get shellToolReplace;

  /// Organize tool row: deletes the selected pages (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shellToolDelete;

  /// Organize tool row: splits the document into several files (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get shellToolSplit;

  /// Organize tool row: combines several files into one PDF (FmWindow; the same words as the start screen's Combine files, FmStart).
  ///
  /// In en, this message translates to:
  /// **'Combine files'**
  String get shellToolCombineFiles;

  /// Organize tool row: crops the pages (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get shellToolCrop;

  /// Organize tool row: sets the page numbering, such as i, ii, iii (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Page labels'**
  String get shellToolPageLabels;

  /// Organize tool row: hint at the end of the row (FmWindow organizeHint).
  ///
  /// In en, this message translates to:
  /// **'Drag pages to reorder. Right-click for more.'**
  String get shellOrganizeHint;

  /// Screen-reader name of the Convert mode's tool row (FmWindow Toolbar label).
  ///
  /// In en, this message translates to:
  /// **'Convert tools'**
  String get shellConvertTools;

  /// Convert tool row: converts the PDF to a Word document (FmWindow). A product name.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get shellConvertWord;

  /// Convert tool row: converts the PDF to an Excel spreadsheet (FmWindow). A product name.
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get shellConvertExcel;

  /// Convert tool row: converts the PDF to a PowerPoint presentation (FmWindow). A product name.
  ///
  /// In en, this message translates to:
  /// **'PowerPoint'**
  String get shellConvertPowerPoint;

  /// Convert tool row: converts the pages to images (FmWindow). A noun.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get shellConvertImage;

  /// Convert tool row: converts the PDF to a web page (FmWindow). A format name.
  ///
  /// In en, this message translates to:
  /// **'HTML'**
  String get shellConvertHtml;

  /// Convert tool row: converts the PDF to plain text (FmWindow). A noun: the plain-text format.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get shellConvertText;

  /// Convert tool row: converts the PDF to Markdown (FmWindow). A format name.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get shellConvertMarkdown;

  /// Convert tool row: creates a PDF from other files (FmWindow; the same words as the start screen's Create PDF, FmStart).
  ///
  /// In en, this message translates to:
  /// **'Create PDF'**
  String get shellToolCreatePdf;

  /// Convert tool row: scans paper into a PDF (FmWindow; the same word as the Scan tool of the mobile home, FmMHome tools). A verb.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get shellToolScan;

  /// Convert tool row: recognizes the text of scanned pages (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Recognize text (OCR)'**
  String get shellToolRecognizeText;

  /// Screen-reader name of the Protect mode's tool row (FmWindow Toolbar label).
  ///
  /// In en, this message translates to:
  /// **'Protect tools'**
  String get shellProtectTools;

  /// Protect tool row: blacks out content for good (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Redact'**
  String get shellToolRedact;

  /// Protect tool row: finds text and patterns to black out (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Find & redact'**
  String get shellToolFindRedact;

  /// Protect tool row: protects the PDF with a password (FmWindow). A noun.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get shellToolPassword;

  /// Protect tool row: removes metadata and other hidden content (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Remove hidden information'**
  String get shellToolRemoveHidden;

  /// Protect tool row: shows what the document contains and allows (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Security report'**
  String get shellToolSecurityReport;

  /// Protect tool row: the red button that blacks out the marked content for good (FmWindow applyLabel).
  ///
  /// In en, this message translates to:
  /// **'Apply redactions'**
  String get shellApplyRedactions;

  /// Tools row: makes the PDF smaller (FmWindow; the same word as the Compress tool of the mobile home, FmMHome tools). A verb.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get shellToolCompress;

  /// Tools row: compares two versions of a document (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get shellToolCompare;

  /// Tools row: checks and fixes the PDF for screen readers (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get shellToolAccessibility;

  /// Tools row: archiving (PDF/A) and print checks (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'PDF/A & preflight'**
  String get shellToolPdfA;

  /// Tools row: runs a series of steps on many files (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Batch actions'**
  String get shellToolBatch;

  /// Tools row: prints the document (FmWindow). A verb.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get shellToolPrint;

  /// Tools row: shows the saved versions of the document (FmWindow).
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get shellToolVersionHistory;

  /// Accessible name of the context menu a right click opens on a text field (B017).
  ///
  /// In en, this message translates to:
  /// **'Text field'**
  String get fieldContextMenu;

  /// Text field context menu: cut the selected text.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get fieldCut;

  /// Text field context menu: copy the selected text.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fieldCopy;

  /// Text field context menu: paste the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get fieldPaste;

  /// Text field context menu: select all the field's text.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get fieldSelectAll;

  /// Accessible name of the invisible drag handle on the sidebar's edge that changes its width (B094).
  ///
  /// In en, this message translates to:
  /// **'Resize sidebar'**
  String get shellResizeSidebar;

  /// Accessible name of the invisible drag handle on the right panel's edge that changes its width (B094).
  ///
  /// In en, this message translates to:
  /// **'Resize panel'**
  String get shellResizePanel;

  /// Screen-reader name of the sidebar and of its row of tabs (FmSidebar t.sidebar).
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get shellSidebar;

  /// Sidebar tab and heading: page thumbnails (FmSidebar t.pages).
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get shellSidebarPages;

  /// Sidebar tab and heading: the document's bookmarks (FmSidebar t.outline).
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get shellSidebarOutline;

  /// Sidebar tab and heading: files embedded in the PDF (FmSidebar t.attachments).
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get shellSidebarAttachments;

  /// Sidebar tab and heading: layers that can be shown or hidden (FmSidebar t.layers).
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get shellSidebarLayers;

  /// Sidebar tab and heading: the signatures in the document (FmSidebar t.signatures).
  ///
  /// In en, this message translates to:
  /// **'Signatures'**
  String get shellSidebarSignatures;

  /// Sidebar tab and heading: results of a search in the document (FmSidebar t.search).
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get shellSidebarSearch;

  /// Sidebar: tooltip and screen-reader name of the info button that explains the small badges on page thumbnails (FmSidebar t.legend).
  ///
  /// In en, this message translates to:
  /// **'What the page badges mean'**
  String get shellPageBadgesLegend;

  /// Sidebar Outline tab: tooltip and screen-reader name of the + button that adds a bookmark (FmSidebar).
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get shellAddBookmark;

  /// Tooltip and screen-reader name of the "…" buttons that open a menu with more actions, in the sidebar and the right panel (FmSidebar, FmDocPanel; the same word as FmEditPanel t.more).
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get shellMore;

  /// Tool row: tooltip and screen-reader name of the "…" button that appears when the window is too narrow for every tool, and the name of the menu it opens with the tools that do not fit (G21).
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get shellMoreTools;

  /// Tool row: the Review edits button as an entry of the "More tools" menu of a narrow window (G21), with the number of edits waiting for review (the row shows it as a badge). {count} is already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Review edits ({count})'**
  String shellReviewEditsCount(String count);

  /// Mode bar: tooltip and screen-reader hint of the sidebar or right-panel toggle when the window is too narrow for that panel beside the document, even on its own (G21; reachable on the web and narrow tablets, below the 1024 px desktop minimum). The toggle is disabled while this shows.
  ///
  /// In en, this message translates to:
  /// **'Make the window wider to show this panel'**
  String get shellWindowTooNarrow;

  /// Sidebar Attachments tab: tooltip and screen-reader name of the + button that embeds a file in the PDF (FmSidebar).
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get shellAttachFile;

  /// Title of the right panel that shows the document's properties (FmDocPanel title).
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get shellPanelDocument;

  /// Screen-reader name of the large area where the document's pages show (the canvas).
  ///
  /// In en, this message translates to:
  /// **'Document pages'**
  String get shellCanvas;

  /// Status bar: tooltip and screen-reader name of the up-arrow button (FmWindow t.prev).
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get shellPreviousPage;

  /// Status bar: tooltip and screen-reader name of the down-arrow button (FmWindow t.next).
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get shellNextPage;

  /// Status bar: the current page and the number of pages (FmWindow t.page). {page} and {count} are already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String shellPageOf(String page, String count);

  /// Status bar: the document was saved on this computer, and when (FmWindow t.saved). {time} is the time of day, already formatted for the region, for example 14:32.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device · {time}'**
  String shellSavedOnDevice(String time);

  /// Status bar: the document is being saved now (FmWindow t.saving).
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get shellSaving;

  /// Status bar: the last save failed (FmWindow t.saveError).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save'**
  String get shellSaveError;

  /// Status bar: the document cannot be saved in place (FmWindow t.readonly).
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get shellReadOnly;

  /// Product name. A proper noun: do not translate; keep the Latin spelling in every language.
  ///
  /// In en, this message translates to:
  /// **'Ferman'**
  String get appName;

  /// Tooltip and screen-reader hint on every control whose feature is not built yet; the control stays visible and disabled (brief, design gap G10). Keep it short: it appears in a small tooltip bubble.
  ///
  /// In en, this message translates to:
  /// **'Available in a future version'**
  String get availableInFutureVersion;

  /// Tooltip and screen-reader name of the window's minimize caption button on Windows and Linux (FmWindow t.minimize). Use the operating system's own word for this button.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// Tooltip and screen-reader name of the window's maximize caption button on Windows and Linux (FmWindow t.maximize). Use the operating system's own word for this button.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// Tooltip and screen-reader name of the maximize caption button while the window is maximized: it returns the window to its previous size. Not in the design; use the operating system's own word (Windows: Restore).
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// Tooltip and screen-reader name of the window's close caption button on Windows and Linux (FmWindow t.closeWin). Closes the window, not a document.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// Label of the app-language choice: the radio group of the first-run language picker (a1-1, aria-label) and the select in Settings › Language and region (a11-1b, FmSettings t.appLang).
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageAppLanguage;

  /// Caption beside the language that is the operating system's language, in the first-run language picker (a1-1, LANGS[0]). Short: it sits at the end of a list row.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// Caption on a language that has no translation yet; choosing it shows the interface in English until volunteers translate it (design gap G20). Short: it sits at the end of a list row.
  ///
  /// In en, this message translates to:
  /// **'Not translated yet'**
  String get languageNotTranslated;

  /// One option of the app-language list in Settings › Language and region for a language that has no translation yet: the language's own name, then the not-translated caption (design gap G20). Choosing it shows the interface in English until volunteers translate it. You may change the separator or put the caption first.
  ///
  /// In en, this message translates to:
  /// **'{language} · Not translated yet'**
  String languageOptionNotTranslated(String language);

  /// The English language, named in the interface language: a document-language badge in Settings › Language and region (a11-1b, FmSettings t.en).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEnglish;

  /// The Turkish language, named in the interface language: a document-language badge in Settings › Language and region (a11-1b, FmSettings t.tr).
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageNameTurkish;

  /// The Arabic language, named in the interface language: a document-language badge in Settings › Language and region (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageNameArabic;

  /// Heading of the first-run language picker (a1-1).
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get onboardingLanguageTitle;

  /// Text under the heading of the first-run language picker (a1-1) while the selected language is the operating system's. {language} is the language's own name, such as English or Türkçe. Settings › Language and region names the settings pane; keep the › separator.
  ///
  /// In en, this message translates to:
  /// **'{language} is selected because it’s your system language. You can change it any time in Settings › Language and region.'**
  String onboardingLanguageSubtitleSystem(String language);

  /// Text under the heading of the first-run language picker (a1-1) once a language other than the system's is selected. Settings › Language and region names the settings pane; keep the › separator.
  ///
  /// In en, this message translates to:
  /// **'You can change it any time in Settings › Language and region.'**
  String get onboardingLanguageSubtitle;

  /// Placeholder of the search field of the first-run language picker (a1-1). It asks in several languages on purpose, so people who don't read the interface language can still find theirs: keep the other languages and put this language's phrase first.
  ///
  /// In en, this message translates to:
  /// **'Search languages · Dil ara · Sprache suchen · ابحث عن لغة'**
  String get onboardingLanguageSearchPlaceholder;

  /// Screen-reader name of the search field of the first-run language picker (a1-1).
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get onboardingLanguageSearchLabel;

  /// Shown in the first-run language picker (a1-1) when the search finds no language. {query} is what the person typed.
  ///
  /// In en, this message translates to:
  /// **'No language matches “{query}”.'**
  String onboardingLanguageNoMatch(String query);

  /// The line under onboardingLanguageNoMatch in the first-run language picker's empty state (a1-1, a2-3m's EmptyState).
  ///
  /// In en, this message translates to:
  /// **'Search by the language’s own name, its English name or its code.'**
  String get onboardingLanguageNoMatchBody;

  /// Footer of the first-run language picker (a1-1), before the Help translate Ferman link.
  ///
  /// In en, this message translates to:
  /// **'Missing your language?'**
  String get onboardingLanguageMissing;

  /// Link in the footer of the first-run language picker (a1-1) to the community translation project.
  ///
  /// In en, this message translates to:
  /// **'Help translate Ferman'**
  String get onboardingLanguageHelpTranslate;

  /// Button that leaves the first-run language picker for the welcome steps (a1-1).
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// Step counter above the heading of a first-run welcome step (a1-2b, a1-2c), such as 1 of 2. The numbers come already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{step} of {count}'**
  String onboardingStep(String step, String count);

  /// Screen-reader name of the step dots at the bottom of a first-run welcome step (a1-2b, a1-2c). The numbers come already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {count}'**
  String onboardingStepLabel(String step, String count);

  /// Button at the bottom start of a first-run welcome step that goes straight to the start screen (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Button that returns to the previous first-run step (a1-2b, a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// Button that moves to the next first-run welcome step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Button on the last first-run welcome step that ends first run and opens the start screen (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Start using Ferman'**
  String get onboardingStartUsing;

  /// Heading of the first-run privacy step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Everything stays on your device'**
  String get onboardingPrivacyTitle;

  /// Text under the heading of the first-run privacy step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Ferman opens, edits, signs and recognizes text on this computer. There’s no account to create and nothing to upload.'**
  String get onboardingPrivacyBody;

  /// Title of a privacy fact on the first-run privacy step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Files stay on this device'**
  String get onboardingPrivacyFilesTitle;

  /// Text of the privacy fact Files stay on this device (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Ferman reads and writes files where they are. Nothing is uploaded.'**
  String get onboardingPrivacyFilesBody;

  /// Title of a privacy fact on the first-run privacy step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get onboardingPrivacyOfflineTitle;

  /// Text of the privacy fact Works offline (a1-2b). OCR is optical character recognition.
  ///
  /// In en, this message translates to:
  /// **'Editing, OCR, signing and conversion need no connection.'**
  String get onboardingPrivacyOfflineBody;

  /// Title of a privacy fact on the first-run privacy step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'No account'**
  String get onboardingPrivacyAccountTitle;

  /// Text of the privacy fact No account (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'There’s nothing to sign up for and nothing to sign in to.'**
  String get onboardingPrivacyAccountBody;

  /// Title of a privacy fact on the first-run privacy step (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'No telemetry'**
  String get onboardingPrivacyTelemetryTitle;

  /// Text of the privacy fact No telemetry (a1-2b).
  ///
  /// In en, this message translates to:
  /// **'Ferman doesn’t collect usage data or crash reports.'**
  String get onboardingPrivacyTelemetryBody;

  /// Title of the first of the four times Ferman uses the network, on the first-run privacy step (a1-2b, design gap G24).
  ///
  /// In en, this message translates to:
  /// **'One optional check for updates'**
  String get onboardingPrivacyUpdatesTitle;

  /// Text of the update-check row on the first-run privacy step (a1-2b, G24). Platform means the operating system.
  ///
  /// In en, this message translates to:
  /// **'Once a day, sending only the version number and platform. You can turn it off.'**
  String get onboardingPrivacyUpdatesBody;

  /// Title of the network use for downloading text-recognition (OCR) language packs, on the first-run privacy step (a1-2b, G24). Name OCR packs: the interface languages are bundled with the app and never downloaded (G52).
  ///
  /// In en, this message translates to:
  /// **'OCR language packs'**
  String get onboardingPrivacyPacksTitle;

  /// Text of the language-pack row on the first-run privacy step (a1-2b, G24).
  ///
  /// In en, this message translates to:
  /// **'Downloaded only when you choose to. Off until you use it.'**
  String get onboardingPrivacyPacksBody;

  /// Title of the network use of the optional AI assistant, on the first-run privacy step (a1-2b, G24). Same words as the AI assistant settings pane.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get onboardingPrivacyAiTitle;

  /// Text of the AI row on the first-run privacy step (a1-2b, G24): the assistant runs a local model, or sends questions to a provider with the person's own key.
  ///
  /// In en, this message translates to:
  /// **'Runs on this computer, or uses your own API key. Off until you use it.'**
  String get onboardingPrivacyAiBody;

  /// Title of the network use for timestamp servers when signing, on the first-run privacy step (a1-2b, G24).
  ///
  /// In en, this message translates to:
  /// **'Signature timestamps'**
  String get onboardingPrivacyTimestampsTitle;

  /// Text of the timestamp row on the first-run privacy step (a1-2b, G24).
  ///
  /// In en, this message translates to:
  /// **'Contacts the timestamp server you chose when you sign. Off until you use it.'**
  String get onboardingPrivacyTimestampsBody;

  /// Link at the bottom of the first-run privacy step that opens Settings › Privacy (a1-2b, G24). Keep the › separator.
  ///
  /// In en, this message translates to:
  /// **'See every connection in Settings › Privacy'**
  String get onboardingPrivacySettingsLink;

  /// Heading of the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Free forever, nothing locked'**
  String get onboardingFreeTitle;

  /// Text under the heading of the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Every feature is included, with no trial, no subscription and no paid tier. Ferman is open source, so anyone can read, check and improve the code.'**
  String get onboardingFreeBody;

  /// The software licence on the last first-run welcome step (a1-2c, design gap G13). Apache-2.0 is the licence's name: do not translate it.
  ///
  /// In en, this message translates to:
  /// **'Licence: Apache-2.0'**
  String get onboardingFreeLicence;

  /// Link to Ferman's source code on the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get onboardingFreeSourceCode;

  /// Link to ways of supporting Ferman on the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Support the project'**
  String get onboardingFreeSupport;

  /// Feature tile on the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Edit text and images'**
  String get onboardingFeatureEditing;

  /// Feature tile on the last first-run welcome step (a1-2c). OCR is optical character recognition.
  ///
  /// In en, this message translates to:
  /// **'Text recognition (OCR)'**
  String get onboardingFeatureOcr;

  /// Feature tile on the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Fill and sign forms'**
  String get onboardingFeatureFillSign;

  /// Feature tile on the last first-run welcome step (a1-2c). e-imza is the Turkish electronic signature: keep the word.
  ///
  /// In en, this message translates to:
  /// **'e-imza and digital signatures'**
  String get onboardingFeatureSignatures;

  /// Feature tile on the last first-run welcome step (a1-2c): removing confidential content for good.
  ///
  /// In en, this message translates to:
  /// **'Redaction'**
  String get onboardingFeatureRedaction;

  /// Feature tile on the last first-run welcome step (a1-2c): Word, Excel and PowerPoint files.
  ///
  /// In en, this message translates to:
  /// **'Convert to and from Office'**
  String get onboardingFeatureConvert;

  /// Feature tile on the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Compare documents'**
  String get onboardingFeatureCompare;

  /// Feature tile on the last first-run welcome step (a1-2c): one action on many files.
  ///
  /// In en, this message translates to:
  /// **'Batch actions'**
  String get onboardingFeatureBatch;

  /// Feature tile on the last first-run welcome step (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Accessibility checker'**
  String get onboardingFeatureAccessibility;

  /// Feature tile on the last first-run welcome step (a1-2c) with the number of languages the interface is translated into (design gap G20). {formatted} is the number written for the region; {count} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} interface language} other{{formatted} interface languages}}'**
  String onboardingFeatureLanguages(int count, String formatted);

  /// Screen-reader name of the green check on a feature tile whose feature this version has (a1-2c).
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get onboardingFeatureIncluded;

  /// Title of the first action card on the start screen (a1-5, FmStart open). The ellipsis says that a file chooser follows.
  ///
  /// In en, this message translates to:
  /// **'Open file…'**
  String get startOpenFile;

  /// Description of the Open file action card on the start screen (a1-5). Speaks of PDFs only until conversion exists (design gap G11).
  ///
  /// In en, this message translates to:
  /// **'PDF files'**
  String get startOpenFileDescription;

  /// Title of an action card on the start screen (a1-5, FmStart create).
  ///
  /// In en, this message translates to:
  /// **'Create PDF'**
  String get startCreatePdf;

  /// Description of the Create PDF action card on the start screen (a1-5).
  ///
  /// In en, this message translates to:
  /// **'From a blank page, files or the clipboard'**
  String get startCreatePdfDescription;

  /// Title of an action card on the start screen (a1-5, FmStart combine).
  ///
  /// In en, this message translates to:
  /// **'Combine files'**
  String get startCombineFiles;

  /// Description of the Combine files action card on the start screen (a1-5).
  ///
  /// In en, this message translates to:
  /// **'Merge several files into one PDF'**
  String get startCombineFilesDescription;

  /// Title of an action card on the start screen (a1-5, FmStart scan).
  ///
  /// In en, this message translates to:
  /// **'Scan to PDF'**
  String get startScanToPdf;

  /// Description of the Scan to PDF action card on the start screen (a1-5).
  ///
  /// In en, this message translates to:
  /// **'From a scanner or a phone camera'**
  String get startScanToPdfDescription;

  /// Label before the row of quick-tool buttons on the start screen (a1-5, FmStart quick).
  ///
  /// In en, this message translates to:
  /// **'Quick tools'**
  String get startQuickTools;

  /// Quick-tool button on the start screen: make a PDF smaller (a1-5).
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get startToolCompress;

  /// Quick-tool button on the start screen: convert to or from PDF (a1-5).
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get startToolConvert;

  /// Quick-tool button on the start screen: sign a PDF (a1-5).
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get startToolSign;

  /// Quick-tool button on the start screen: make scanned text selectable (a1-5). OCR is optical character recognition.
  ///
  /// In en, this message translates to:
  /// **'Recognize text (OCR)'**
  String get startToolOcr;

  /// Quick-tool button on the start screen: passwords and permissions (a1-5).
  ///
  /// In en, this message translates to:
  /// **'Protect'**
  String get startToolProtect;

  /// Quick-tool button on the start screen: compare two versions of a document (a1-5).
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get startToolCompare;

  /// Headline of the drop area of the empty start screen (a1-5, FmStart emptyTitle).
  ///
  /// In en, this message translates to:
  /// **'Drop a PDF here'**
  String get startDropTitle;

  /// Text under Drop a PDF here on the empty start screen (a1-5). Speaks of PDFs only until conversion exists (design gap G11).
  ///
  /// In en, this message translates to:
  /// **'or open one from your computer.'**
  String get startDropSubtitle;

  /// Note at the bottom of the drop area of the empty start screen (a1-5, FmStart emptyFoot).
  ///
  /// In en, this message translates to:
  /// **'Files stay on this device. Ferman never uploads them.'**
  String get startDropFootnote;

  /// Main button of the drop area of the empty start screen (a1-5, DropZone).
  ///
  /// In en, this message translates to:
  /// **'Open a PDF'**
  String get startOpenPdf;

  /// Second button of the drop area of the empty start screen (a1-5, DropZone).
  ///
  /// In en, this message translates to:
  /// **'New blank PDF'**
  String get startNewBlankPdf;

  /// Title of the warning banner at the top of the start screen when the engine library or PDFium, the page renderer, is missing or broken (G101). Opening files stays off, with this title as the reason.
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t open PDF files right now.'**
  String get startEngineUnavailableTitle;

  /// Message of the warning banner at the top of the start screen when Ferman cannot open PDF files because a part of the app is missing or broken (G101).
  ///
  /// In en, this message translates to:
  /// **'A part of Ferman is missing or doesn’t match this version. Installing Ferman again fixes this.'**
  String get startEngineUnavailableMessage;

  /// Button of the start screen’s warning banner (G101): copies the technical facts about the missing or broken part, in English, for a bug report (as a1-9b’s link).
  ///
  /// In en, this message translates to:
  /// **'Copy technical details'**
  String get startCopyTechnicalDetails;

  /// Heading of the settings window and screen-reader name of its pane list (a11-1, FmSettings t.settings).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Placeholder and screen-reader name of the search field above the settings panes (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearch;

  /// Tooltip and screen-reader name of the button that closes settings and returns to where the person was. Settings opens inside the main window in this version.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get settingsClose;

  /// Title of the warning banner at the top of Settings when a change could not be written to the settings file on this device. The change still applies while Ferman runs.
  ///
  /// In en, this message translates to:
  /// **'Your settings couldn’t be saved.'**
  String get settingsSaveFailedTitle;

  /// Message of the warning banner at the top of Settings when a change could not be saved: the change is kept for this session only and is gone at the next start.
  ///
  /// In en, this message translates to:
  /// **'This change applies until you close Ferman.'**
  String get settingsSaveFailedMessage;

  /// Screen-reader name of the button that hides the could-not-save banner in Settings.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get settingsSaveFailedDismiss;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsPaneGeneral;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Language and region'**
  String get settingsPaneLanguage;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get settingsPaneEditing;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get settingsPaneFonts;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Signatures and certificates'**
  String get settingsPaneSignatures;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). OCR is optical character recognition.
  ///
  /// In en, this message translates to:
  /// **'Text recognition (OCR)'**
  String get settingsPaneOcr;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get settingsPaneAi;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPanePrivacy;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get settingsPaneUpdates;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get settingsPaneShortcuts;

  /// A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav).
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsPaneAdvanced;

  /// Label of the appearance choice in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Theme choice in Settings › General: follow the operating system's light or dark appearance (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Match system'**
  String get settingsThemeSystem;

  /// Theme choice in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Theme choice in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Label of the choice of how PDF pages look while the dark theme is on, in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'PDF pages in dark theme'**
  String get settingsPageTheme;

  /// Choice under PDF pages in dark theme (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Paper white'**
  String get settingsPagePaper;

  /// Description of the choice Paper white (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Pages look exactly as printed.'**
  String get settingsPagePaperDescription;

  /// Choice under PDF pages in dark theme (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Dimmed'**
  String get settingsPageDimmed;

  /// Description of the choice Dimmed (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Slightly darker with a trace of sepia. Colours aren’t inverted.'**
  String get settingsPageDimmedDescription;

  /// Choice under PDF pages in dark theme (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Dark reading mode'**
  String get settingsPageDark;

  /// Description of the choice Dark reading mode (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Light text on dark pages. Images keep their colours. Never printed.'**
  String get settingsPageDarkDescription;

  /// Label of a select in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Page layout for new documents'**
  String get settingsPageLayout;

  /// Option of Page layout for new documents (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Continuous scroll'**
  String get settingsPageLayoutScroll;

  /// Option of Page layout for new documents (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Single page'**
  String get settingsPageLayoutSingle;

  /// Option of Page layout for new documents (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Two-page spread'**
  String get settingsPageLayoutSpread;

  /// Label of the default-zoom select in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get settingsZoom;

  /// Option of Zoom: the page fills the window's width (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get settingsZoomFitWidth;

  /// Option of Zoom: the whole page fits in the window (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Fit page'**
  String get settingsZoomFitPage;

  /// Switch in Settings › General (a11-1).
  ///
  /// In en, this message translates to:
  /// **'Reopen documents from last time'**
  String get settingsReopen;

  /// Text beside the Make Ferman the default button in Settings › General (from the default-app dialog, a1-3).
  ///
  /// In en, this message translates to:
  /// **'Ferman can be the app that opens when you double-click a PDF.'**
  String get settingsDefaultApp;

  /// Text beside the Make Ferman the default button in Settings › General on Windows (a11-1w), instead of settingsDefaultApp: Windows does not let apps make themselves the default, so the button opens Windows Settings › Default apps (design gap G16). Use the names of the Windows Settings pages in your language.
  ///
  /// In en, this message translates to:
  /// **'Ferman can be the app that opens when you double-click a PDF. Windows lets you choose it in Settings › Default apps.'**
  String get settingsDefaultAppWindows;

  /// Button in Settings › General that makes Ferman the app that opens PDFs (a11-1). The ellipsis says that the system asks to confirm.
  ///
  /// In en, this message translates to:
  /// **'Make Ferman the default…'**
  String get settingsMakeDefault;

  /// Hint under the app-language select in Settings › Language and region (a11-1b, FmSettings t.appLangHint).
  ///
  /// In en, this message translates to:
  /// **'Ferman switches right away. No restart needed.'**
  String get settingsAppLanguageHint;

  /// Label of the languages used for documents that don't name theirs, in Settings › Language and region (a11-1b, FmSettings t.docLang).
  ///
  /// In en, this message translates to:
  /// **'Document languages'**
  String get settingsDocumentLanguages;

  /// Hint under Document languages in Settings › Language and region (a11-1b, FmSettings t.docLangHint).
  ///
  /// In en, this message translates to:
  /// **'Used for text recognition, spell-check and hyphenation when a document doesn’t say its language.'**
  String get settingsDocumentLanguagesHint;

  /// Button that adds a document language in Settings › Language and region (a11-1b, FmSettings t.add).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get settingsAddDocumentLanguage;

  /// Statement at the top of Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Ferman collects nothing.'**
  String get settingsPrivacyStatement;

  /// Text under Ferman collects nothing. in Settings › Privacy, before the list of network uses (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'No usage data, no crash reports, no document contents, no account. Files stay on this device. These are the only times Ferman connects to the internet, and each can be turned off:'**
  String get settingsPrivacyStatementBody;

  /// A network use in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsNetUpdates;

  /// Description of Check for updates in Settings › Privacy (a11-1h). Platform means the operating system.
  ///
  /// In en, this message translates to:
  /// **'Once a day; sends only the version number and platform.'**
  String get settingsNetUpdatesDescription;

  /// A network use in Settings › Privacy (a11-1h): asking whether a certificate was revoked. Not enabled until the owner decides (design gap G51).
  ///
  /// In en, this message translates to:
  /// **'Signature checks'**
  String get settingsNetSignatureChecks;

  /// Description of Signature checks in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Asks the certificate provider whether a certificate was revoked, when you sign or open a signed file.'**
  String get settingsNetSignatureChecksDescription;

  /// A network use in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Timestamps'**
  String get settingsNetTimestamps;

  /// Description of Timestamps in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Contacts the timestamp server you chose when you sign.'**
  String get settingsNetTimestampsDescription;

  /// A network use in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Downloads you start'**
  String get settingsNetDownloads;

  /// Description of Downloads you start in Settings › Privacy (a11-1h). OCR is optical character recognition; the assistant is the AI assistant.
  ///
  /// In en, this message translates to:
  /// **'OCR language packs and the assistant’s model.'**
  String get settingsNetDownloadsDescription;

  /// A network use in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Your AI provider'**
  String get settingsNetAiProvider;

  /// Description of Your AI provider in Settings › Privacy (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Only if you add your own API key. Off.'**
  String get settingsNetAiProviderDescription;

  /// Button in Settings › Privacy that lists the connections Ferman made (a11-1h).
  ///
  /// In en, this message translates to:
  /// **'Show network activity…'**
  String get settingsNetworkActivity;

  /// Label of the region select in Settings › Language and region: the region drives dates, numbers, paper size, units and the first day of the week (a11-1b, FmSettings t.region).
  ///
  /// In en, this message translates to:
  /// **'Region formats'**
  String get regionFormats;

  /// Label in Settings › Language and region (a11-1b, FmSettings t.paper).
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get regionPaperSize;

  /// The ISO A4 paper size (a11-1b). Usually kept as A4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get regionPaperA4;

  /// The US Letter paper size (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get regionPaperLetter;

  /// Label of the length-unit choice in Settings › Language and region (a11-1b, FmSettings t.units).
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get regionUnits;

  /// Label in Settings › Language and region (a11-1b, FmSettings t.week).
  ///
  /// In en, this message translates to:
  /// **'First day of the week'**
  String get regionFirstDay;

  /// Option of First day of the week (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get regionMonday;

  /// Option of First day of the week (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get regionSunday;

  /// Option of First day of the week (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get regionSaturday;

  /// Option of First day of the week, shown for regions whose week starts on Friday (a11-1b, design gap G34).
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get regionFriday;

  /// Heading of the box of example values in Settings › Language and region; shown in capitals (a11-1b, FmSettings t.example).
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get regionExamples;

  /// Row of the examples box: a date in the region's format (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get regionExampleDate;

  /// Row of the examples box: a time in the region's format (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get regionExampleTime;

  /// Row of the examples box: a number in the region's format (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get regionExampleNumber;

  /// Row of the examples box: a font size in the region's format (a11-1b).
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get regionExampleFontSize;

  /// Canvas: the title of the placeholder of a page that failed to render (a2-13, G30). {page} is the page number, already formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Ferman couldn’t draw page {page}.'**
  String viewerPageFailed(String page);

  /// Canvas: the plain reason under the title of a page that failed to render (a2-13).
  ///
  /// In en, this message translates to:
  /// **'Something on this page can’t be read. The rest of the document works as usual.'**
  String get viewerPageFailedReason;

  /// Canvas: the button that renders a failed page again (a2-13).
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get viewerTryAgain;

  /// Canvas: the label beside the rectangle of Marquee zoom while it is dragged (a2-2). {zoom} is the zoom it gives, a percentage already formatted for the region, for example 180%.
  ///
  /// In en, this message translates to:
  /// **'Release to zoom to {zoom}'**
  String viewerMarqueeZoom(String zoom);

  /// Edit mode: the tooltip beside the pointer over an editable text block (a3-1a). {block} is the start of the block's first line, as the document writes it, for example Madde 3.
  ///
  /// In en, this message translates to:
  /// **'Click to edit · {block}'**
  String editHoverTip(String block);

  /// Edit mode: the title of the right panel's callout for text that cannot be edited (a3-19, G39).
  ///
  /// In en, this message translates to:
  /// **'This text can’t be edited'**
  String get editNotEditableTitle;

  /// Edit mode: the tooltip beside the pointer over a scanned page without text (a3-11).
  ///
  /// In en, this message translates to:
  /// **'No text on this page yet · Recognize text to edit'**
  String get editTipImageOnly;

  /// Edit mode: the panel callout's message for a scanned page without text (a3-11, G39).
  ///
  /// In en, this message translates to:
  /// **'This page is an image, such as a scan. Recognize its text to edit it.'**
  String get editBodyImageOnly;

  /// Edit mode: the tooltip over text drawn as vector shapes (a3-19).
  ///
  /// In en, this message translates to:
  /// **'This text is drawn as shapes, so it can’t be edited'**
  String get editTipOutlinedText;

  /// Edit mode: the panel callout's message for text drawn as vector shapes (a3-19).
  ///
  /// In en, this message translates to:
  /// **'This text is drawn as vector shapes, not letters. Ferman can’t change it without redrawing it.'**
  String get editBodyOutlinedText;

  /// Edit mode: the tooltip over text whose glyphs have no Unicode mapping (G39).
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t read the letters of this text'**
  String get editTipUnknownText;

  /// Edit mode: the panel callout's message for text without a Unicode mapping (G39).
  ///
  /// In en, this message translates to:
  /// **'Its font doesn’t say which letters its shapes stand for, so Ferman can’t change it safely.'**
  String get editBodyUnknownText;

  /// Edit mode: the tooltip over invisible text, such as recognized text over a scan (G39).
  ///
  /// In en, this message translates to:
  /// **'This text is invisible'**
  String get editTipInvisibleText;

  /// Edit mode: the panel callout's message for invisible text (G39).
  ///
  /// In en, this message translates to:
  /// **'It’s hidden text, such as recognized text over a scan. Ferman doesn’t edit it.'**
  String get editBodyInvisibleText;

  /// Edit mode: the tooltip over text of a document whose permissions forbid changes (G27, G39).
  ///
  /// In en, this message translates to:
  /// **'The author’s permissions don’t allow editing'**
  String get editTipRestricted;

  /// Edit mode: the panel callout's message for a restricted document (G27, G39).
  ///
  /// In en, this message translates to:
  /// **'Unlock the document with its owner password to edit it.'**
  String get editBodyRestricted;

  /// Edit mode: the tooltip over text of a document Ferman opened read-only, such as an XFA form (G39).
  ///
  /// In en, this message translates to:
  /// **'This document is read-only'**
  String get editTipReadOnly;

  /// Edit mode: the panel callout's message for a read-only document (G39).
  ///
  /// In en, this message translates to:
  /// **'Ferman opened this document for viewing only, so its text can’t be changed.'**
  String get editBodyReadOnly;

  /// Edit mode: the tooltip over text of a repaired document, or one whose readers disagree (a1-9, G39).
  ///
  /// In en, this message translates to:
  /// **'This document was repaired, so it can’t be edited'**
  String get editTipDamaged;

  /// Edit mode: the panel callout's message for a repaired document (a1-9, G39).
  ///
  /// In en, this message translates to:
  /// **'Ferman found problems in this file and opened it for viewing only. Save a repaired copy to edit it.'**
  String get editBodyDamaged;

  /// Edit mode: the tooltip over text inside a signature field (G39).
  ///
  /// In en, this message translates to:
  /// **'This text is part of a signature'**
  String get editTipSignature;

  /// Edit mode: the panel callout's message for text inside a signature field (G39).
  ///
  /// In en, this message translates to:
  /// **'Ferman never edits signatures.'**
  String get editBodySignature;

  /// Edit mode: the tooltip over text inside an annotation or form field (G39).
  ///
  /// In en, this message translates to:
  /// **'This text belongs to a comment or form field'**
  String get editTipAnnotation;

  /// Edit mode: the panel callout's message for text inside an annotation or form field (G39). Use the mode names of the mode bar.
  ///
  /// In en, this message translates to:
  /// **'Change it in Comment or Fill & Sign mode.'**
  String get editBodyAnnotation;

  /// Edit mode: the tooltip over text the engine cannot rewrite safely (G39).
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t change this text safely'**
  String get editTipTooComplex;

  /// Edit mode: the panel callout's message for a page that hit a resource limit (G39).
  ///
  /// In en, this message translates to:
  /// **'This page is too large or complex for Ferman to rewrite safely.'**
  String get editBodyLimits;

  /// Edit mode: the panel callout's message for text whose operator is split across two content streams (G39).
  ///
  /// In en, this message translates to:
  /// **'Its drawing instructions are split across two parts of the page, so Ferman can’t rewrite it safely.'**
  String get editBodySplit;

  /// Edit mode: the panel callout's message for sheared text (G39).
  ///
  /// In en, this message translates to:
  /// **'This text is slanted, so Ferman can’t rewrite it safely.'**
  String get editBodySkewed;

  /// Canvas: the accessible name of the context menu a right click opens on page text with the Select tool (B106).
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get viewerTextMenu;

  /// Status bar: the accessible name of the page field, which takes a page number or a page label (a2-13, ⌘G).
  ///
  /// In en, this message translates to:
  /// **'Page number'**
  String get viewerPageNumber;

  /// Sidebar: a page thumbnail's accessible name and a signature field's page (a2-3p, a2-14). {page} is the page number formatted for the region, or the page's label such as iv.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String sidebarPage(String page);

  /// Sidebar › Outline: the title of the empty state when the document has no outline (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'No bookmarks'**
  String get sidebarNoBookmarks;

  /// Sidebar › Outline: the line under the empty state's title (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'This document has no outline. Add a bookmark to mark a place you want to come back to.'**
  String get sidebarNoBookmarksBody;

  /// Sidebar › Attachments: the title of the empty state (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'No attachments'**
  String get sidebarNoAttachments;

  /// Sidebar › Attachments: the line under the empty state's title (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'Files embedded in this PDF appear here.'**
  String get sidebarNoAttachmentsBody;

  /// Sidebar › Layers: the title of the empty state (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'No layers'**
  String get sidebarNoLayers;

  /// Sidebar › Layers: the line under the empty state's title (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'This document has no layers to show or hide.'**
  String get sidebarNoLayersBody;

  /// Sidebar › Signatures: the title of the empty state (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'No signatures'**
  String get sidebarNoSignatures;

  /// Sidebar › Signatures: the line under the empty state's title (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'This document isn’t signed and has no signature fields.'**
  String get sidebarNoSignaturesBody;

  /// Sidebar › Attachments: the note under the list (a2-3b).
  ///
  /// In en, this message translates to:
  /// **'Attachments open in their own app. Ferman doesn’t run embedded files.'**
  String get sidebarAttachmentsNote;

  /// Sidebar › Attachments: the download button of an attachment, which saves it where the user picks (a2-3b).
  ///
  /// In en, this message translates to:
  /// **'Save attachment as…'**
  String get sidebarSaveAttachment;

  /// Sidebar › Layers: the note under the list (a2-3c).
  ///
  /// In en, this message translates to:
  /// **'Hidden layers still print unless you turn off “Print hidden layers” in Print.'**
  String get sidebarLayersNote;

  /// Sidebar › Layers: the eye button of a shown layer (a2-3c).
  ///
  /// In en, this message translates to:
  /// **'Hide layer'**
  String get sidebarHideLayer;

  /// Sidebar › Layers: the eye button of a hidden layer (a2-3c).
  ///
  /// In en, this message translates to:
  /// **'Show layer'**
  String get sidebarShowLayer;

  /// Sidebar › Layers: the accessible name of the lock beside a layer whose visibility the document locks (a2-3c).
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get sidebarLayerLocked;

  /// Sidebar › Signatures: the line under a signer's name until signatures are checked (a2-14, design gap G31).
  ///
  /// In en, this message translates to:
  /// **'Signature checking is available in a future version.'**
  String get sidebarSignatureCheckingLater;

  /// Sidebar › Signatures: the line under an unsigned signature field's name (a2-14).
  ///
  /// In en, this message translates to:
  /// **'Empty signature field'**
  String get sidebarEmptySignatureField;

  /// The find bar's accessible name (a2-4a, SearchReplaceBar).
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get findRegion;

  /// The find field's placeholder and name (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findField;

  /// The replace field's placeholder; replace comes in P2 (B045).
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get findReplaceWith;

  /// Find option and toggle (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get findMatchCase;

  /// Find option and toggle (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Whole words'**
  String get findWholeWords;

  /// Find option and toggle (a2-4a); disabled for a future version.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get findRegex;

  /// The find bar's disclosure while the replace row is hidden.
  ///
  /// In en, this message translates to:
  /// **'Show replace'**
  String get findShowReplace;

  /// The find bar's disclosure while the replace row shows.
  ///
  /// In en, this message translates to:
  /// **'Hide replace'**
  String get findHideReplace;

  /// The find bar's previous button (⇧↵).
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get findPrevious;

  /// The find bar's next button (↵).
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get findNext;

  /// The find bar's Replace all button; P2 (B045).
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get findReplaceAll;

  /// The find bar's count when nothing matches (a2-4d), in the danger colour.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get findNoResults;

  /// The group of match options under the find bar (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Search options'**
  String get findOptions;

  /// The options group's first heading (a2-4a, shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get findMatch;

  /// Find option, on by default (a2-4a, G61).
  ///
  /// In en, this message translates to:
  /// **'Ignore accents and dotted/dotless i'**
  String get findIgnoreAccents;

  /// The description under Ignore accents (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'“i” finds İ, ı and î; “c” finds ç; “kira” finds KİRA. On by default.'**
  String get findIgnoreAccentsBody;

  /// The options group's second heading (a2-4a, shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Look in'**
  String get findLookIn;

  /// Look in: the pages' text (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Page text'**
  String get findPageText;

  /// Look in: comments already in the file (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get findComments;

  /// Look in: form field values (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Form fields'**
  String get findFormFields;

  /// Look in: bookmark titles (a2-4a).
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get findBookmarks;

  /// Under a long search's progress (a2-4c).
  ///
  /// In en, this message translates to:
  /// **'Matches appear as they’re found.'**
  String get findSearchingBody;

  /// Stops a long search (a2-4c), also Esc.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get findCancel;

  /// No results: the action that widens the search (a2-4d).
  ///
  /// In en, this message translates to:
  /// **'Also search comments and fields'**
  String get findNoneAction;

  /// The find bar's count, a polite live region (a2-4a); numbers in the region's format.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String findCount(String current, String total);

  /// The status bar's inline task while a search runs (FmWindow task, B124), before "Page N of M".
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get statusSearching;

  /// A long search's progress (a2-4c); numbers in the region's format.
  ///
  /// In en, this message translates to:
  /// **'Searching · page {page} of {pages}'**
  String findSearching(String page, String pages);

  /// No results: the title, with the query as typed (a2-4d).
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String findNoneTitle(String query);

  /// No results: what was searched and how, with Ignore accents on (a2-4d). count is the page count, pages the same number in the region's format.
  ///
  /// In en, this message translates to:
  /// **'Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}, ignoring accents and dotted/dotless i. Comments and form fields weren’t searched.'**
  String findNoneBody(int count, String pages);

  /// No results: what was searched, with Ignore accents off (a2-4d). count is the page count, pages the same number in the region's format.
  ///
  /// In en, this message translates to:
  /// **'Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}. Comments and form fields weren’t searched.'**
  String findNoneBodyExact(int count, String pages);

  /// Sidebar › Search results: the field's accessible name (a2-3e).
  ///
  /// In en, this message translates to:
  /// **'Search in document'**
  String get sidebarSearchField;

  /// Accessible name of a search result found in a bookmark's title (Look in › Bookmarks).
  ///
  /// In en, this message translates to:
  /// **'Bookmark: {title}'**
  String sidebarSearchBookmark(String title);

  /// Sidebar › Search results: the title of the empty state when the document has no text layer, such as a scan (a2-3m).
  ///
  /// In en, this message translates to:
  /// **'No text to search'**
  String get sidebarSearchNoTextTitle;

  /// Sidebar › Search results: the line under the no-text empty state's title (a2-3m); recognizing text is OCR.
  ///
  /// In en, this message translates to:
  /// **'These pages are scanned images. Recognizing text makes them searchable.'**
  String get sidebarSearchNoTextBody;

  /// Sidebar › Search results: the summary under the field (a2-3e). matches and pages are counts, matchesText and pagesText the same numbers in the region's format.
  ///
  /// In en, this message translates to:
  /// **'{matches, plural, =1{1 match} other{{matchesText} matches}} on {pages, plural, =1{1 page} other{{pagesText} pages}}'**
  String sidebarSearchSummary(
    int matches,
    String matchesText,
    int pages,
    String pagesText,
  );

  /// Name of the file-type filter in the system open panel (a1-13): the panel lists only PDF files.
  ///
  /// In en, this message translates to:
  /// **'PDF documents'**
  String get openPdfFilter;

  /// Title of the start screen’s danger banner when a file did not open (a1-9b’s title, G116). {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t open “{name}”'**
  String openFailedTitle(String name);

  /// Accessible name of the close button of the banner of openFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get openFailedDismiss;

  /// Status bar: a document just opened, with no save in this session yet (FmWindow t.saved without its time).
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get shellSavedOnDeviceUndated;

  /// Accessible name of the menu behind “+N” in the title bar (a1-10).
  ///
  /// In en, this message translates to:
  /// **'More open documents'**
  String get shellMoreDocumentsMenu;

  /// Heading of the “+N” menu (a1-10): how many documents have no tab in the title bar. {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more document} other{{countText} more documents}}'**
  String shellMoreDocumentsHeading(int count, String countText);

  /// An item of the “+N” menu (a1-10) for a document with unsaved changes: its file name, then the mark. {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'{name} · unsaved'**
  String shellMoreDocumentsUnsaved(String name);

  /// Item of the “+N” menu (a1-10).
  ///
  /// In en, this message translates to:
  /// **'Show all open documents'**
  String get shellShowAllDocuments;

  /// Item of the “+N” menu (a1-10): closes every document but the active one, asking about unsaved ones.
  ///
  /// In en, this message translates to:
  /// **'Close other documents…'**
  String get shellCloseOtherDocuments;

  /// Headline of the overlay while files are dragged over the window (a1-6, FmStart dropN without its count: the files are named only once dropped, G117).
  ///
  /// In en, this message translates to:
  /// **'Drop to open the files'**
  String get dropOverlayTitle;

  /// Line under dropOverlayTitle (a1-6, FmStart dropHow).
  ///
  /// In en, this message translates to:
  /// **'Move over a choice, then let go.'**
  String get dropOverlayHint;

  /// Title of the drop target that opens each dropped file in its own tab (a1-6, FmStart dropTabs without its count, G117).
  ///
  /// In en, this message translates to:
  /// **'Open in tabs'**
  String get dropOverlayTabs;

  /// Line under dropOverlayTabs (a1-6, FmStart dropTabsSub, the PDF-only line of G11).
  ///
  /// In en, this message translates to:
  /// **'Each file opens on its own.'**
  String get dropOverlayTabsDescription;

  /// Title of the drop target that would merge the dropped files, disabled until combining ships (a1-6, FmStart dropCombine, B104).
  ///
  /// In en, this message translates to:
  /// **'Combine into one PDF'**
  String get dropOverlayCombine;

  /// Title of the drop strip above the recent files (a1-4-m2, FmStart drop).
  ///
  /// In en, this message translates to:
  /// **'Drop files anywhere in this window'**
  String get startDropStripTitle;

  /// Line under startDropStripTitle until conversion ships (a1-4-m2, FmStart dropSubPdf, G11).
  ///
  /// In en, this message translates to:
  /// **'PDF files open in tabs.'**
  String get startDropStripSubtitle;

  /// Heading of the pinned files on the start screen (a1-4, FmStart pinned).
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get startPinned;

  /// Accessible name and tooltip of the button that pins a recent file above the list (not drawn, G118).
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get startPin;

  /// Accessible name and tooltip of a pinned file’s pin button (a1-4, FmStart unpin).
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get startUnpin;

  /// Heading of the recent files on the start screen (a1-4, FmStart recent).
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get startRecent;

  /// Placeholder and accessible name of the recent files’ search field (a1-4, FmStart searchRecent).
  ///
  /// In en, this message translates to:
  /// **'Search recent files'**
  String get startSearchRecent;

  /// Accessible name of the recent files’ sort menu (a1-4, the Select’s aria-label).
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get startSort;

  /// Sort option: most recently opened first (a1-4, FmStart sort).
  ///
  /// In en, this message translates to:
  /// **'Last opened'**
  String get startSortOpened;

  /// Sort option and list column: the file name, in the UI language’s order (a1-4, FmStart sort, name).
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get startSortName;

  /// Sort option and list column: the folder the file is in (a1-4, FmStart sort, where).
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get startSortLocation;

  /// Accessible name of the grid and list switch of the recent files (a1-4, FmStart view).
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get startView;

  /// Tooltip of the grid view of the recent files (a1-4, FmStart grid).
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get startViewGrid;

  /// Tooltip of the list view of the recent files (a1-4c, FmStart list).
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get startViewList;

  /// Column of the recent files’ list: the page count (a1-4c, FmStart pagesH).
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get startColumnPages;

  /// Column of the recent files’ list: when the file was last opened (a1-4c, FmStart opened).
  ///
  /// In en, this message translates to:
  /// **'Last opened'**
  String get startColumnOpened;

  /// Note under the recent files (a1-4, FmStart footer).
  ///
  /// In en, this message translates to:
  /// **'Recent files are listed only on this device.'**
  String get startRecentFooter;

  /// Link under the recent files that empties the list but for the pinned files (a1-4, FmStart clear).
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get startClearList;

  /// Shown in place of the recent files when the search finds none (not drawn, G118).
  ///
  /// In en, this message translates to:
  /// **'No recent file matches “{query}”.'**
  String startNoRecentMatch(String query);

  /// A recent file’s page count, after its time (a1-4, FmStart pages); pages is the count in the region’s digits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{pages} pages}}'**
  String startPages(int count, String pages);

  /// When a recent file was opened today, with the region’s time (a1-4, FmStart).
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String startOpenedToday(String time);

  /// When a recent file was opened yesterday, with the region’s time (a1-4, FmStart).
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String startOpenedYesterday(String time);

  /// Neutral badge of a recent file that carries signatures, before signature checking ships (a1-4-m2, FmStart signedNeutral).
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get startBadgeSigned;

  /// Badge on a recent file that has form fields (a1-4, accent).
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get startBadgeForm;

  /// Badge on a recent file whose first page has no text, most likely a scan (a1-4, neutral).
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get startBadgeScanned;

  /// Title of the dialog for a recent file that was moved, renamed or deleted (a1-9e, missTitle); name is the file name, isolated.
  ///
  /// In en, this message translates to:
  /// **'“{name}” can’t be found'**
  String startMissingTitle(String name);

  /// Line under startMissingTitle (a1-9e, missDesc); folder is where the file was, “~” for the home folder, isolated.
  ///
  /// In en, this message translates to:
  /// **'It was moved, renamed or deleted after you last opened it. It was in {folder}.'**
  String startMissingDescription(String folder);

  /// Button of a1-9e that takes the missing file off the recent files (a1-9e, remove).
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get startMissingRemove;

  /// Button of a1-9e that opens the system open panel to find the file where it is now (a1-9e, locate).
  ///
  /// In en, this message translates to:
  /// **'Locate…'**
  String get startMissingLocate;

  /// Accessible name of a1-9e’s close button, which keeps the file in the list (G118).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get startMissingClose;

  /// The line of an error tab (a1-9b) for a bug in Ferman.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong inside Ferman. Copy the technical details to report it.'**
  String get errorInternal;

  /// The line of an error tab (a1-9b) for a file that is gone.
  ///
  /// In en, this message translates to:
  /// **'The file isn’t there any more. It may have been moved, renamed or deleted.'**
  String get errorFileNotFound;

  /// The line of an error tab (a1-9b) for a file the system does not let Ferman read (G119).
  ///
  /// In en, this message translates to:
  /// **'This computer doesn’t let Ferman read the file. Check who may open it, or copy it to a folder of yours.'**
  String get errorFilePermissionDenied;

  /// The line of an error tab (a1-9b) when reading the file failed.
  ///
  /// In en, this message translates to:
  /// **'Ferman couldn’t read the file from its disk. Check that the disk is still connected, then try again.'**
  String get errorFileRead;

  /// The line of a1-9c’s error tab under openNotPdfTitle. {name} is the file name (G119: the kind of file is not named).
  ///
  /// In en, this message translates to:
  /// **'“{name}” isn’t a PDF file. Ferman opens PDF files.'**
  String errorNotPdf(String name);

  /// Title of the unlock dialog over a locked tab (a1-8).
  ///
  /// In en, this message translates to:
  /// **'This PDF is password-protected'**
  String get errorPasswordRequired;

  /// Error under the password field of the unlock dialog (a1-8b).
  ///
  /// In en, this message translates to:
  /// **'That password didn’t work. Check Caps Lock and the keyboard layout: on a Turkish keyboard ı and i are different keys.'**
  String get errorWrongPassword;

  /// The line of an error tab (a1-9b) for a damaged file.
  ///
  /// In en, this message translates to:
  /// **'The file is damaged and Ferman can’t repair it. Try getting the file again.'**
  String get errorDamaged;

  /// The line of a1-9b’s error tab for a truncated file (without the board’s size, G119).
  ///
  /// In en, this message translates to:
  /// **'The file stops before its end and the rest is missing. It was probably cut off while downloading or copying. Try getting the file again.'**
  String get errorDamagedTruncated;

  /// The line of an error tab (a1-9b) for a file with a PDF header and no objects.
  ///
  /// In en, this message translates to:
  /// **'The file starts like a PDF, but nothing after that is readable. Try getting the file again.'**
  String get errorDamagedEmpty;

  /// The line of an error tab (a1-9b) for a file Ferman does not support yet (a2-10a: certificate encryption).
  ///
  /// In en, this message translates to:
  /// **'It uses something Ferman doesn’t support yet, such as encryption with a certificate.'**
  String get errorUnsupported;

  /// Message of a1-9f’s toast when a resource limit stopped the open.
  ///
  /// In en, this message translates to:
  /// **'This file is too complex to open within Ferman’s safety limits. Your other documents are open and unchanged.'**
  String get errorTooComplex;

  /// Message of a1-9f’s toast.
  ///
  /// In en, this message translates to:
  /// **'This computer ran out of memory while opening it. Your other documents are open and unchanged.'**
  String get errorOutOfMemory;

  /// Title of a1-9f’s toast (and the start screen’s banner) when a file ran out of memory or past a limit while opening. {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'“{name}” was closed'**
  String openClosedTitle(String name);

  /// Action of a1-9f’s toast: opens the file again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get openTryAgain;

  /// Title of a1-9c’s error tab.
  ///
  /// In en, this message translates to:
  /// **'That file isn’t a PDF.'**
  String get openNotPdfTitle;

  /// Primary button of an error tab (a1-9b, a1-9c): shows the open panel.
  ///
  /// In en, this message translates to:
  /// **'Open another file…'**
  String get openAnotherFile;

  /// Button of an error tab on macOS (a1-9b, a1-9c).
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get openShowInFinder;

  /// Button of an error tab on Windows (a1-9b, a1-9c; G119).
  ///
  /// In en, this message translates to:
  /// **'Show in File Explorer'**
  String get openShowInExplorer;

  /// Button of an error tab on Linux (a1-9b, a1-9c; G119).
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get openShowInFolder;

  /// Disabled button of a1-9c’s error tab until conversion ships (P3).
  ///
  /// In en, this message translates to:
  /// **'Convert to PDF…'**
  String get openConvertToPdf;

  /// Description of the unlock dialog (a1-8). {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Enter the password for “{name}”. Ferman forgets it when you close the file.'**
  String unlockDescription(String name);

  /// Label of the unlock dialog’s field (a1-8).
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get unlockPassword;

  /// Checkbox of the unlock dialog (a1-8).
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get unlockShowPassword;

  /// Button of the unlock dialog (a1-8): closes the locked tab.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get unlockCancel;

  /// Primary button of the unlock dialog (a1-8).
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get unlockOpen;

  /// Title of the bar above the pages of a document whose author restricted it (a2-10a).
  ///
  /// In en, this message translates to:
  /// **'The author restricted this document.'**
  String get restrictedTitle;

  /// Message of the restricted bar (a2-10a), shown when printing is allowed and changes, comments and form filling are not.
  ///
  /// In en, this message translates to:
  /// **'You can read and print it. Editing, comments and form filling are turned off.'**
  String get restrictedBody;

  /// Message of the restricted bar for any other set of permissions (G106; not on a board).
  ///
  /// In en, this message translates to:
  /// **'You can read it. The author turned some actions off.'**
  String get restrictedBodyOther;

  /// Button of the restricted bar (a2-10a) that opens the owner-password dialog.
  ///
  /// In en, this message translates to:
  /// **'Unlock with owner password…'**
  String get restrictedUnlock;

  /// Title of the owner-password dialog (G106; not on a board).
  ///
  /// In en, this message translates to:
  /// **'Unlock with owner password'**
  String get ownerUnlockTitle;

  /// Text of the owner-password dialog (G106). {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Enter the owner password for “{name}”. Ferman forgets it when you close the file.'**
  String ownerUnlockDescription(String name);

  /// Label of the owner-password dialog's field (G106).
  ///
  /// In en, this message translates to:
  /// **'Owner password'**
  String get ownerUnlockPassword;

  /// Primary button of the owner-password dialog (G106).
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get ownerUnlockAction;

  /// Title of the bar above the pages of a document with scripts (G100; not on a board). {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This document contains 1 script.} other{This document contains {countText} scripts.}}'**
  String scriptsTitle(int count, String countText);

  /// Message of the scripts bar (G100), a8-4's sentence.
  ///
  /// In en, this message translates to:
  /// **'Ferman never runs scripts; other apps might.'**
  String get scriptsBody;

  /// Screen-reader name of the scripts bar's dismiss button (G100).
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get scriptsDismiss;

  /// a1-9: title of the bar above the pages of a file Ferman repaired on open.
  ///
  /// In en, this message translates to:
  /// **'Ferman repaired this file.'**
  String get repairedTitle;

  /// a1-9: message of the repaired bar. {count} is how many repairs the engine reports (0 when it names none), {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Problems were fixed in this copy.} =1{1 problem was fixed in this copy.} other{{countText} problems were fixed in this copy.}} The original stays as it was until you save.'**
  String repairedBody(int count, String countText);

  /// a1-9: the repaired bar's button that opens the list of repairs (What Ferman repaired).
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get repairedDetails;

  /// a1-9: the repaired bar's button that saves the repaired file as a new file (disabled until saving ships, B103).
  ///
  /// In en, this message translates to:
  /// **'Save repaired copy…'**
  String get repairedSave;

  /// a1-9: title of the popover that lists the repairs.
  ///
  /// In en, this message translates to:
  /// **'What Ferman repaired'**
  String get repairDetailsTitle;

  /// a1-9: button in the repairs popover that copies the list of repairs.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get repairCopyDetails;

  /// a1-9: a repair: the file's table of where its objects are was rebuilt.
  ///
  /// In en, this message translates to:
  /// **'The cross-reference table was broken'**
  String get repairXrefTitle;

  /// a1-9: detail of the cross-reference repair. {count} is the objects found, {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rebuilt from the 1 object found in the file.} other{Rebuilt from the {countText} objects found in the file.}}'**
  String repairXrefBody(int count, String countText);

  /// a1-9: second sentence of the cross-reference repair's detail. {count} is the document's pages, {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The page is present.} other{All {countText} pages are present.}}'**
  String repairPagesPresent(int count, String countText);

  /// a1-9: a repair: the file's trailer (the part that says where the document starts) was missing (not on the board).
  ///
  /// In en, this message translates to:
  /// **'The file’s trailer was missing'**
  String get repairTrailerTitle;

  /// a1-9: detail of the trailer repair (not on the board).
  ///
  /// In en, this message translates to:
  /// **'Ferman found where the document starts among its objects.'**
  String get repairTrailerBody;

  /// a1-9: a repair: data streams whose stated length was wrong (not on the board). {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stream had the wrong length} other{{countText} streams had the wrong length}}'**
  String repairStreamsTitle(int count, String countText);

  /// a1-9: detail of the stream-length repair (not on the board).
  ///
  /// In en, this message translates to:
  /// **'Ferman read each one up to its end.'**
  String get repairStreamsBody;

  /// a1-9: objects of the file that could not be read (not on the board). {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 object couldn’t be read} other{{countText} objects couldn’t be read}}'**
  String repairUnreadableTitle(int count, String countText);

  /// a1-9: detail of the unreadable objects (not on the board).
  ///
  /// In en, this message translates to:
  /// **'Pages and features that use them may be incomplete.'**
  String get repairUnreadableBody;

  /// a11-7c: title of the bar above the pages of an XFA-only form.
  ///
  /// In en, this message translates to:
  /// **'This is an XFA form, which Ferman can’t show.'**
  String get xfaTitle;

  /// a11-7c: message of the XFA bar.
  ///
  /// In en, this message translates to:
  /// **'XFA is a discontinued Adobe format. Open it in Adobe Acrobat Reader, or ask the sender for a regular PDF.'**
  String get xfaBody;

  /// G102: title of the bar above the pages of a file whose two parsers disagree (not on a board). {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Ferman opened “{name}” read-only.'**
  String disagreeTitle(String name);

  /// G102: message of the parsers-disagree bar (not on a board).
  ///
  /// In en, this message translates to:
  /// **'Parts of this file don’t match each other, which can mean it is damaged. You can read it as usual.'**
  String get disagreeBody;

  /// Right panel section with the file's facts (FmDocPanel `view`).
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get propertiesFile;

  /// Right panel section listing the document's fonts (FmDocPanel).
  ///
  /// In en, this message translates to:
  /// **'Fonts in this document'**
  String get propertiesFonts;

  /// Right panel section, the properties dialog's Security tab and its Summary row (FmDocPanel, a2-7, a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get propertiesSecurity;

  /// Label of the page count (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get propertiesPages;

  /// Label of the first page's size (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get propertiesPageSize;

  /// Label of the file's size (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get propertiesFileSize;

  /// Label of the PDF version (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'PDF version'**
  String get propertiesVersion;

  /// A PDF version with the Acrobat version that introduced it, as a2-7 shows it: '1.7 (Acrobat 8.x)'.
  ///
  /// In en, this message translates to:
  /// **'{version} (Acrobat {acrobat}.x)'**
  String propertiesVersionAcrobat(String version, String acrobat);

  /// Label of the file's path (FmDocPanel).
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get propertiesLocation;

  /// Label of the creation date (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get propertiesCreated;

  /// Label of the modification date (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get propertiesModified;

  /// Label of the document's title (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get propertiesTitle;

  /// Label of the document's author (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get propertiesAuthor;

  /// Label of the document's subject (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get propertiesSubject;

  /// Label of the document's keywords (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get propertiesKeywords;

  /// Label: whether the PDF is tagged (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Tagged PDF'**
  String get propertiesTagged;

  /// Label: whether the PDF is linearized (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Fast web view'**
  String get propertiesFastWebView;

  /// Label of the application that wrote the PDF (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Made with'**
  String get propertiesMadeWith;

  /// A yes/no value (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get propertiesYes;

  /// A yes/no value (a2-7).
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get propertiesNo;

  /// A value the file does not give (a2-10b's 'Password to open: None'; also empty metadata, not on a board).
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get propertiesNone;

  /// An unencrypted document's security (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'No password'**
  String get propertiesNoPassword;

  /// Security of a document restricted by an owner password, opening without one (not on a board).
  ///
  /// In en, this message translates to:
  /// **'Owner password'**
  String get propertiesOwnerPassword;

  /// Signatures in the document (a2-7: 'No password · 1 signature'). {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 signature} other{{countText} signatures}}'**
  String propertiesSignatures(int count, String countText);

  /// The one signature of a document and its page (FmDocPanel). {page} is formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'1 signature, page {page}'**
  String propertiesSignatureOnPage(String page);

  /// A font whose program is in the file (FmDocPanel, a2-7).
  ///
  /// In en, this message translates to:
  /// **'Embedded'**
  String get propertiesEmbedded;

  /// A subset font in the right panel (FmDocPanel).
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get propertiesPartial;

  /// Note under a subset font in the right panel (FmDocPanel, without its missing letters, which come with M3).
  ///
  /// In en, this message translates to:
  /// **'Subset: only characters already in the file.'**
  String get propertiesPartialNote;

  /// A subset font in the properties dialog (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Subset'**
  String get propertiesSubset;

  /// Note under a subset font in the properties dialog (a2-7, without its missing letters, which come with M3).
  ///
  /// In en, this message translates to:
  /// **'Only the characters already used.'**
  String get propertiesSubsetNote;

  /// A font whose program is not in the file (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Not embedded'**
  String get propertiesNotEmbedded;

  /// A font type in the properties dialog's Type column (a2-7); a format name.
  ///
  /// In en, this message translates to:
  /// **'Type 1'**
  String get propertiesFontType1;

  /// A font type (Multiple Master Type 1) in the Type column (a2-7); a format name.
  ///
  /// In en, this message translates to:
  /// **'Multiple Master'**
  String get propertiesFontMultipleMaster;

  /// A font type in the Type column (a2-7); a format name.
  ///
  /// In en, this message translates to:
  /// **'TrueType'**
  String get propertiesFontTrueType;

  /// A composite font in the Type column (a2-7); a format name.
  ///
  /// In en, this message translates to:
  /// **'Type 0'**
  String get propertiesFontType0;

  /// A font drawn by the file itself, in the Type column (a2-7); a format name.
  ///
  /// In en, this message translates to:
  /// **'Type 3'**
  String get propertiesFontType3;

  /// Any other font type, in the Type column (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get propertiesFontOther;

  /// Column heading of the fonts table, shown in capitals (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get propertiesFontColumn;

  /// Column heading of the fonts table, shown in capitals (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get propertiesTypeColumn;

  /// Column heading of the fonts table, shown in capitals (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get propertiesStatusColumn;

  /// Title of the properties dialog (a2-7, a2-10b).
  ///
  /// In en, this message translates to:
  /// **'{name} — Properties'**
  String propertiesDialogTitle(String name);

  /// Accessible name of the properties dialog's tabs (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get propertiesSection;

  /// Tab of the properties dialog (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get propertiesSummary;

  /// Tab of the properties dialog (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get propertiesAdvanced;

  /// Closes the properties dialog (a2-7, a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get propertiesDone;

  /// Accessible name of the properties dialog's close button and scrim (not on a board).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get propertiesClose;

  /// Label of the encryption method (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get propertiesEncryption;

  /// RC4 encryption with its key length (a2-10b's Encryption row; not on a board). {bits} is formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'RC4, {bits}-bit'**
  String propertiesRc4(String bits);

  /// AES-128 encryption (a2-10b's Encryption row); a method name.
  ///
  /// In en, this message translates to:
  /// **'AES-128'**
  String get propertiesAes128;

  /// AES-256 encryption (a2-10b's Encryption row); a method name.
  ///
  /// In en, this message translates to:
  /// **'AES-256'**
  String get propertiesAes256;

  /// After the encryption method of a restricted file (a2-10b: 'AES-256 · owner password').
  ///
  /// In en, this message translates to:
  /// **'owner password'**
  String get propertiesOwnerPasswordSuffix;

  /// Label: whether opening needs a password (a2-10b); also a document's security when it does (not on a board).
  ///
  /// In en, this message translates to:
  /// **'Password to open'**
  String get propertiesOpenPassword;

  /// Opening needs a password (a2-10b's row; not on a board).
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get propertiesRequired;

  /// Heading of the permissions, shown in capitals (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get propertiesPermissions;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Printing'**
  String get propertiesPrinting;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Changing the document'**
  String get propertiesChanging;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Adding comments'**
  String get propertiesCommenting;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Filling form fields'**
  String get propertiesFilling;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Signing'**
  String get propertiesSigning;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Copying text and images'**
  String get propertiesCopying;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Text access for screen readers'**
  String get propertiesScreenReaders;

  /// A permission (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Assembling pages'**
  String get propertiesAssembling;

  /// A permission's state (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get propertiesAllowed;

  /// Printing allowed at full quality (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Allowed, high quality'**
  String get propertiesAllowedHighQuality;

  /// A permission's state (a2-10b).
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get propertiesNotAllowed;

  /// Label of the document's language tag in the Advanced tab (not on a board).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get propertiesLanguage;

  /// Label of the scripts row in the Advanced tab (G100, a8-3's row name).
  ///
  /// In en, this message translates to:
  /// **'JavaScript'**
  String get propertiesScripts;

  /// The scripts row of the Advanced tab, in a8-3's words (G100; not on a board). {countText} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A script that runs when the file opens. Ferman never runs it.} other{{countText} scripts that run when the file opens. Ferman never runs them.}}'**
  String propertiesScriptsValue(int count, String countText);

  /// a1-7: the title of the progress card while a file takes long to open. {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Opening “{name}”'**
  String openingTitle(String name);

  /// a1-7: the progress card's button (also Esc) that stops opening the file and closes its tab.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get openingCancel;

  /// Title of the first-run question that offers to make Ferman the app that opens PDF files (a1-3), asked after onboarding on macOS.
  ///
  /// In en, this message translates to:
  /// **'Open PDFs with Ferman?'**
  String get defaultAppTitle;

  /// Line under defaultAppTitle (a1-3).
  ///
  /// In en, this message translates to:
  /// **'Ferman can be the app that opens when you double-click a PDF. macOS asks you to confirm the change.'**
  String get defaultAppDescription;

  /// Label before the app that opens PDF files now, an arrow and Ferman (a1-3).
  ///
  /// In en, this message translates to:
  /// **'Opens PDFs now:'**
  String get defaultAppNow;

  /// Button of a1-3 that closes the question; Settings › General keeps the button.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get defaultAppNotNow;

  /// Primary button of a1-3: asks macOS to make Ferman the app that opens PDF files.
  ///
  /// In en, this message translates to:
  /// **'Use Ferman for PDFs'**
  String get defaultAppUse;

  /// Checkbox of a1-3: with it, Not now never asks again.
  ///
  /// In en, this message translates to:
  /// **'Don’t ask again'**
  String get defaultAppDontAsk;

  /// Text beside Make Ferman the default… in Settings › General on macOS (a11-1); app is the app that opens PDF files now, as macOS names it, isolated.
  ///
  /// In en, this message translates to:
  /// **'{app} opens PDFs on this Mac.'**
  String settingsDefaultAppOther(String app);

  /// Text in Settings › General on macOS when Ferman already opens PDF files; the button is then not shown.
  ///
  /// In en, this message translates to:
  /// **'Ferman opens PDFs on this Mac.'**
  String get settingsDefaultAppFerman;

  /// Title of the editor’s danger toast when Save attachment as… failed (a2-3b, G124); name is the attachment’s file name, isolated.
  ///
  /// In en, this message translates to:
  /// **'“{name}” wasn’t saved'**
  String attachmentNotSaved(String name);

  /// Message of the toast of attachmentNotSaved when the file could not be written.
  ///
  /// In en, this message translates to:
  /// **'Ferman couldn’t write the file there. Choose another folder, or check that the disk has space and is still connected.'**
  String get attachmentWriteFailed;

  /// Edit mode: the name of a history step that changed the text of a block, in the Undo history panel (a3-10). {page} is the page number, formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Edited text · page {page}'**
  String editStepText(String page);

  /// Undo history panel (a3-10): tooltip and screen-reader name of the button that closes the panel.
  ///
  /// In en, this message translates to:
  /// **'Close history'**
  String get editHistoryClose;

  /// Undo history panel (a3-10): screen-reader name of the list of history steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get editHistorySteps;

  /// Undo history panel (a3-10): the first row, the document as it was opened. {name} is the file name, isolated.
  ///
  /// In en, this message translates to:
  /// **'Opened {name}'**
  String editHistoryOpened(String name);

  /// Undo history panel (a3-10): the note at the bottom of the panel.
  ///
  /// In en, this message translates to:
  /// **'Click a step to go back to it. Greyed steps can be redone until you make a new change. History is kept until you close the document; saved versions are in Version history.'**
  String get editHistoryNote;

  /// Edit tool row: why Undo is disabled, as its tooltip, when the document has no step to undo (G126).
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo'**
  String get editNothingToUndo;

  /// Edit tool row: why Redo is disabled, as its tooltip, when no step was undone (G126).
  ///
  /// In en, this message translates to:
  /// **'Nothing to redo'**
  String get editNothingToRedo;

  /// Phone navigation bar: its name for screen readers (FmPhone, tabsLabel).
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get phoneSections;

  /// Phone navigation bar: the start screen (FmPhone).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get phoneTabHome;

  /// Phone navigation bar: the file browser (FmPhone).
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get phoneTabFiles;

  /// Phone navigation bar: Scan to PDF (FmPhone).
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get phoneTabScan;

  /// Phone navigation bar: Settings (FmPhone).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get phoneTabSettings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
