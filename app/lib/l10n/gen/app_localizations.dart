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

  /// Placeholder of the language search field at phone width (board a13-1b): the shorter form that fits one line. It shows the word in several languages on purpose, this language first.
  ///
  /// In en, this message translates to:
  /// **'Search · Ara · Suchen · بحث'**
  String get onboardingLanguageSearchPlaceholderPhone;

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

  /// Heading of the first-run editing step (a1-2a).
  ///
  /// In en, this message translates to:
  /// **'Edit any PDF like a document'**
  String get onboardingEditTitle;

  /// First paragraph of the first-run editing step (a1-2a).
  ///
  /// In en, this message translates to:
  /// **'Click any text and type. Ferman keeps the original font, size and spacing, and reflows the paragraph inside its frame.'**
  String get onboardingEditBody;

  /// Second paragraph of the first-run editing step (a1-2a).
  ///
  /// In en, this message translates to:
  /// **'When a font is missing a character, Ferman tells you which one and what it will use instead.'**
  String get onboardingEditGlyphs;

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
  /// **'Edit text'**
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

  /// Phone Settings: a group of the list (a13-15, shown in capitals) and a heading of Language and region (a13-15b).
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get settingsPhoneGroupDocuments;

  /// Phone Settings › Language and region: the heading over the app language (a13-15b).
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsPhoneGroupApp;

  /// Phone Settings › Language and region: the heading over the region formats (a13-15b).
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get settingsPhoneGroupRegion;

  /// Phone Settings: the value of the Privacy row, which states the fact (a13-15). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'No data collected'**
  String get settingsPhonePrivacyValue;

  /// Phone Settings: the row of About and the licences (a13-15).
  ///
  /// In en, this message translates to:
  /// **'About and licence'**
  String get settingsPhoneAbout;

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
  /// **'Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}, ignoring accents and dotted/dotless i.'**
  String findNoneBody(int count, String pages);

  /// No results: what was searched, with Ignore accents off (a2-4d). count is the page count, pages the same number in the region's format.
  ///
  /// In en, this message translates to:
  /// **'Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}.'**
  String findNoneBodyExact(int count, String pages);

  /// a2-4d: after findNoneBody, with Comments ticked in Look in.
  ///
  /// In en, this message translates to:
  /// **'Form fields weren’t searched.'**
  String get findNotSearchedFields;

  /// a2-4d: after findNoneBody, with Comments not ticked.
  ///
  /// In en, this message translates to:
  /// **'Comments and form fields weren’t searched.'**
  String get findNotSearchedBoth;

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

  /// Phone home: the search field's placeholder (FmMHome t.search).
  ///
  /// In en, this message translates to:
  /// **'Search documents'**
  String get startPhoneSearch;

  /// Phone home: a quick tool, one short word under its icon (FmMHome tools).
  ///
  /// In en, this message translates to:
  /// **'Combine'**
  String get startPhoneToolCombine;

  /// Phone home: the text recognition quick tool, the short form under its icon (FmMHome tools).
  ///
  /// In en, this message translates to:
  /// **'OCR'**
  String get startPhoneToolOcr;

  /// Phone home with no files: the title (FmMHome t.emptyTitle).
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get startPhoneEmptyTitle;

  /// Phone home with no files: the line under the title (FmMHome t.emptySub).
  ///
  /// In en, this message translates to:
  /// **'Open a PDF from your phone or a cloud drive, or scan a paper document.'**
  String get startPhoneEmptySubtitle;

  /// Phone home with no files: the first action, a button (FmMHome t.open).
  ///
  /// In en, this message translates to:
  /// **'Open a file'**
  String get startPhoneOpen;

  /// Phone home with no files: the second action, a button (FmMHome t.scan).
  ///
  /// In en, this message translates to:
  /// **'Scan a document'**
  String get startPhoneScan;

  /// Phone home: the link beside Recent to every file (FmMHome t.all).
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get startPhoneSeeAll;

  /// Phone home: the label over the places to open from, shown in capitals through the locale's casing (FmMHome t.import).
  ///
  /// In en, this message translates to:
  /// **'Open from'**
  String get startPhoneOpenFrom;

  /// Phone home: a place to open from, the phone's downloads folder (FmMHome sources).
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get startPhoneSourceDownloads;

  /// Phone home: a place to open from, a product name that stays as it is (FmMHome sources).
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get startPhoneSourceGoogleDrive;

  /// Phone home: a place to open from, a product name that stays as it is (FmMHome sources).
  ///
  /// In en, this message translates to:
  /// **'OneDrive'**
  String get startPhoneSourceOneDrive;

  /// Phone home: heading of the recent files (FmMHome recent).
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get startPhoneRecent;

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

  /// Recent files (a1-4, FmStart): the badge of a file saved after an edit in Ferman.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get startBadgeEdited;

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

  /// Phone: the search field over a long list in a bottom sheet (a13-8c, G129).
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get selectSheetSearch;

  /// Phone: shown when the search finds nothing in a bottom sheet's list (a13-8c).
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get selectSheetNoMatch;

  /// Phone: accessible name of the scrim behind a bottom sheet, which closes it.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get selectSheetClose;

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

  /// Note under a subset font in the right panel (FmDocPanel); propertiesPartialMissing follows it when letters are missing.
  ///
  /// In en, this message translates to:
  /// **'Subset: only characters already in the file.'**
  String get propertiesPartialNote;

  /// After propertiesPartialNote: the letters the subset lacks, each in single quotation marks (FmDocPanel's "No ‘ğ’, ‘Ğ’.").
  ///
  /// In en, this message translates to:
  /// **'No {letters}.'**
  String propertiesPartialMissing(String letters);

  /// A subset font in the properties dialog (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Subset'**
  String get propertiesSubset;

  /// Note under a subset font in the properties dialog (a2-7); propertiesSubsetMissing follows it when letters are missing.
  ///
  /// In en, this message translates to:
  /// **'Only the characters already used.'**
  String get propertiesSubsetNote;

  /// After propertiesSubsetNote: the letters the subset lacks, each in single quotation marks (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Typing {letters} needs a substitute.'**
  String propertiesSubsetMissing(String letters);

  /// Note under a font that is not embedded (a2-7, FmDocPanel): the font the page is drawn in.
  ///
  /// In en, this message translates to:
  /// **'Ferman is showing {font} instead.'**
  String propertiesShownInstead(String font);

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

  /// Edit panel (a3-4, a3-18): the warning's title when the edited text needs more lines than its block's frame.
  ///
  /// In en, this message translates to:
  /// **'Text doesn’t fit'**
  String get editOverflowTitle;

  /// Edit panel (a3-4, a3-18): the overflow warning's message. {n} is the number of lines written for the region; {count} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The edited paragraph needs {n} more line than its frame.} other{The edited paragraph needs {n} more lines than its frame.}}'**
  String editOverflowBody(int count, String n);

  /// Edit panel (a3-4): the choice that grows the block's frame by the lines the engine computed. {n} is the number written for the region; {count} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Extend block by {n} line} other{Extend block by {n} lines}}'**
  String editOverflowExtend(int count, String n);

  /// Edit panel (a3-4): the choice that tightens the block's spacing by the amount the engine computed. {percent} is the percentage written for the region, such as 0.6% or %0,6.
  ///
  /// In en, this message translates to:
  /// **'Tighten spacing slightly (−{percent})'**
  String editOverflowTighten(String percent);

  /// Edit panel (a3-4): the choice that keeps the frame and hides the lines that don't fit, with a warning on the page and its thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Keep and warn'**
  String get editOverflowKeep;

  /// Edit panel (a3-18): why Extend is disabled when a labelled line, such as 'IBAN: …', sits right below the block. {label} is the line's label in the document's own words.
  ///
  /// In en, this message translates to:
  /// **'The {label} line sits right below this block.'**
  String editOverflowExtendLabelBelow(String label);

  /// Edit panel (a3-18): why Extend is disabled when another line sits right below the block. {text} is the start of that line in the document's own words.
  ///
  /// In en, this message translates to:
  /// **'The line “{text}” sits right below this block.'**
  String editOverflowExtendBelow(String text);

  /// Edit panel (a3-18): why Extend is disabled when the block already reaches the edge of the page.
  ///
  /// In en, this message translates to:
  /// **'Extending the block would run it past the page’s edge.'**
  String get editOverflowExtendPageEdge;

  /// Edit panel (a3-18): why Tighten is disabled. {n} is the number of lines still over, written for the region; {count} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Even the tightest allowed spacing leaves {n} line over.} other{Even the tightest allowed spacing leaves {n} lines over.}}'**
  String editOverflowTightenShort(int count, String n);

  /// Edit mode (a3-4, a3-18): the amber status in the page margin beside a block whose last lines Keep and warn hides, and the page thumbnail's warning. {n} is the number written for the region; {count} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+{n} line hidden} other{+{n} lines hidden}}'**
  String editOverflowHidden(int count, String n);

  /// Edit panel (a3-9): the warning's title after a number in a table cell was edited and other cells likely depend on it.
  ///
  /// In en, this message translates to:
  /// **'Totals don’t update'**
  String get editTotalsTitle;

  /// Edit panel (a3-9): the warning's message; the cells that likely depend on the edited one are tinted on the page.
  ///
  /// In en, this message translates to:
  /// **'A PDF stores numbers as text. The marked cells still show the old amounts.'**
  String get editTotalsBody;

  /// Edit panel (a3-9): the button that opens the cells that likely depend on the edited one in Review edits. {n} is the number written for the region; {count} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Review the marked cell} other{Review the {n} marked cells}}'**
  String editTotalsReview(int count, String n);

  /// Edit panel heading (a3-9, FmEditPanel): the badge once the open block's text changed.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get editBadgeEdited;

  /// Edit panel (a3-3a, FmEditPanel): the title of the warning when the block's font has no glyph for a typed character (missing-glyph step 3).
  ///
  /// In en, this message translates to:
  /// **'Missing character'**
  String get editGlyphTitle;

  /// Edit panel (a3-3a, FmEditPanel): the warning's message for one missing character. {chars} is the character in ‘ ’.
  ///
  /// In en, this message translates to:
  /// **'This font has no {chars}. Ferman will use a similar font for this character.'**
  String editGlyphBody(String chars);

  /// Edit panel (a3-3a): the warning's message for several missing characters. {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'This font has no {chars}. Ferman will use a similar font for these characters.'**
  String editGlyphBodyMany(String chars);

  /// Edit panel: the warning's message with Settings › Editing › Keep the original font and mark the character (a11-1c). {chars} is the characters, each in ‘ ’.
  ///
  /// In en, this message translates to:
  /// **'This font has no {chars}. Ferman keeps the original font and marks what’s missing.'**
  String editGlyphMarkedBody(String chars);

  /// Edit panel (a3-3a, a3-17): the button that opens the font picker for the missing characters.
  ///
  /// In en, this message translates to:
  /// **'Choose a font…'**
  String get editGlyphChoose;

  /// Edit panel (a3-3a, a3-17): the button that keeps the missing characters as Ferman drew them.
  ///
  /// In en, this message translates to:
  /// **'Keep as is'**
  String get editGlyphKeep;

  /// Edit panel (a3-17): the title when no font has the missing character.
  ///
  /// In en, this message translates to:
  /// **'No font has this character'**
  String get editGlyphNoneTitle;

  /// Edit panel (a3-17): the message when no font has the missing character. {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'Neither this font nor any font on this computer has {chars}. Choose a font that has it, or keep the character as is.'**
  String editGlyphNoneBody(String chars);

  /// Edit panel (a3-17): the title when the font's licence forbids embedding it for new text.
  ///
  /// In en, this message translates to:
  /// **'This font can’t be embedded'**
  String get editGlyphLicenceTitle;

  /// Edit panel (a3-17): the message when the installed copy of the font allows only preview and print. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'{font} is installed, but its licence allows only preview and print. Ferman will use a similar font for {chars} instead.'**
  String editGlyphLicenceBody(String font, String chars);

  /// Edit panel (a3-17, G37): the message when the installed copy of the font forbids embedding altogether. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'{font} is installed, but its licence doesn’t allow embedding it. Ferman will use a similar font for {chars} instead.'**
  String editGlyphLicenceBodyRestricted(String font, String chars);

  /// Edit panel (a3-17, G37, Q09): the message when the document's own font allows only preview and print. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'The licence of {font} in this document allows only preview and print, so Ferman doesn’t reuse its glyphs. Ferman will use a similar font for {chars} instead.'**
  String editGlyphOwnFontBody(String font, String chars);

  /// Edit panel (a3-17): the notice, said once, when missing-glyph step 2 took the character from the same font installed on this computer.
  ///
  /// In en, this message translates to:
  /// **'Character added from this computer'**
  String get editGlyphAddedTitle;

  /// Edit panel (a3-17): the step 2 notice's message. {chars} is the characters, each in ‘ ’ and separated by the list separator; {font} is the font's name.
  ///
  /// In en, this message translates to:
  /// **'Ferman took {chars} from {font} installed on this computer and added it to the document’s font.'**
  String editGlyphAddedBody(String chars, String font);

  /// Font picker (a3-3b): the dialog's title.
  ///
  /// In en, this message translates to:
  /// **'Choose a font for this block'**
  String get fontPickerTitle;

  /// Font picker (a3-3b): the close button's name.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get fontPickerClose;

  /// Font picker (a3-3b): the name of the scope control.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get fontPickerScope;

  /// Font picker (a3-3b): the scope that sets only the missing characters in the chosen font.
  ///
  /// In en, this message translates to:
  /// **'Missing characters only'**
  String get fontPickerScopeMissing;

  /// Font picker (a3-3b): the scope that sets the whole block in the chosen font (not built yet).
  ///
  /// In en, this message translates to:
  /// **'Whole block'**
  String get fontPickerScopeBlock;

  /// Font picker (a3-3b): the search field's placeholder and name.
  ///
  /// In en, this message translates to:
  /// **'Search fonts'**
  String get fontPickerSearch;

  /// Font picker (a3-3b): the group of the document's own fonts; shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Embedded in this document'**
  String get fontPickerEmbedded;

  /// Font picker (a3-3b): the group of the installed fonts; shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Installed on this computer'**
  String get fontPickerInstalled;

  /// Font picker (a3-3b): the group of the fonts that ship with Ferman; shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Similar fonts included with Ferman'**
  String get fontPickerBundled;

  /// Font picker (a3-3b): the tag of the candidate whose metrics are closest to the original's.
  ///
  /// In en, this message translates to:
  /// **'Closest match'**
  String get fontPickerClosest;

  /// Font picker (a3-3b): the coverage badge of a font with every missing character. {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'Has {chars}'**
  String fontPickerHas(String chars);

  /// Font picker (a3-3b): the coverage badge of a font with none of the missing characters. {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'No {chars}'**
  String fontPickerHasNone(String chars);

  /// Font picker (a3-3b): the coverage badge of a font with some of the missing characters. {covered} and {needed} are numbers written for the region.
  ///
  /// In en, this message translates to:
  /// **'{covered} of {needed} characters'**
  String fontPickerHasSome(String covered, String needed);

  /// Font picker (a3-3b, G37): the badge of a font whose licence forbids using it for new text.
  ///
  /// In en, this message translates to:
  /// **'Can’t be embedded'**
  String get fontPickerNotEmbeddable;

  /// Font picker (a3-3b): shown when the search finds no font. {query} is what was typed.
  ///
  /// In en, this message translates to:
  /// **'No font matches “{query}”.'**
  String fontPickerNoMatch(String query);

  /// Font picker (a3-3b): the button that closes it without a choice.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get fontPickerCancel;

  /// Font picker (a3-3b): the button that sets the missing characters in the selected font. {font} is its name.
  ///
  /// In en, this message translates to:
  /// **'Use {font}'**
  String fontPickerUse(String font);

  /// Toast (a11-6): the title after a commit set characters in a similar font, said once per font.
  ///
  /// In en, this message translates to:
  /// **'Font substituted'**
  String get editFontSubstituted;

  /// Toast (a11-6): the message. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator.
  ///
  /// In en, this message translates to:
  /// **'This block uses {font} for {chars}.'**
  String editFontSubstitutedBody(String font, String chars);

  /// Toast (a11-6): the name of the toast's close button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get editFontSubstitutedDismiss;

  /// Save as sheet (a1-11): the title.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get saveAsTitle;

  /// Save as sheet (a1-11): the file name field's label.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get saveAsName;

  /// Save as sheet: the error under an empty file name.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name.'**
  String get saveAsNameEmpty;

  /// Save as sheet: the error under a file name with a folder separator.
  ///
  /// In en, this message translates to:
  /// **'A file name can’t contain / or \\.'**
  String get saveAsNameInvalid;

  /// Save as sheet: the error under a name a file in the chosen folder already has; the system panel of Other location… asks before replacing.
  ///
  /// In en, this message translates to:
  /// **'A file with this name is already there. Choose another name, or use Other location…'**
  String get saveAsNameTaken;

  /// Save as sheet (a1-11): the label of the folder menu.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get saveAsWhere;

  /// Save as sheet (a1-11): the folder menu's item that opens the system save panel (a1-11b).
  ///
  /// In en, this message translates to:
  /// **'Other location…'**
  String get saveAsOtherLocation;

  /// Save as sheet: the accessible name of the format choices.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get saveAsFormat;

  /// Save as sheet (a1-11): the standard PDF format.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get saveAsPdf;

  /// Save as sheet (a1-11): the line under PDF.
  ///
  /// In en, this message translates to:
  /// **'Standard PDF. Keeps text editable in Ferman and other editors.'**
  String get saveAsPdfDescription;

  /// Save as sheet (a1-11): the archiving format, disabled until P4 (G111).
  ///
  /// In en, this message translates to:
  /// **'PDF/A-2b, for archiving'**
  String get saveAsPdfA;

  /// Save as sheet (a1-11): the web format, disabled until M4 (G111).
  ///
  /// In en, this message translates to:
  /// **'Optimized for web'**
  String get saveAsWeb;

  /// Save as sheet (a1-11): the checkbox that saves a copy and leaves the document as it was.
  ///
  /// In en, this message translates to:
  /// **'Save as a copy'**
  String get saveAsCopy;

  /// Save as sheet (a1-11b): the line under Save as a copy. {name} is the open file's name, {folder} the folder chosen in Where.
  ///
  /// In en, this message translates to:
  /// **'“{name}” stays open and unchanged; the copy is saved in {folder}.'**
  String saveAsCopyDescription(String name, String folder);

  /// Save as sheet (a1-11): a checkbox; without it the file is a copy without comments (B138).
  ///
  /// In en, this message translates to:
  /// **'Include comments and markup'**
  String get saveAsComments;

  /// Save as sheet (a1-11): a checkbox; with it the file is rewritten whole (B138).
  ///
  /// In en, this message translates to:
  /// **'Remove edit history from the file'**
  String get saveAsHistory;

  /// Save as sheet: the button that closes it without saving.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get saveAsCancel;

  /// Save dialogs: the name of the close button and of the backdrop.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get saveAsClose;

  /// Save failure dialog (a11-7, a11-7d): the title. {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save “{name}”'**
  String saveFailedTitle(String name);

  /// Save failure dialog (a11-7): the disk is full.
  ///
  /// In en, this message translates to:
  /// **'The disk is full. Free some space or save somewhere else. Your edits are kept.'**
  String get saveFailedDiskFull;

  /// Save failure dialog (a11-7d): read-only file or permission denied.
  ///
  /// In en, this message translates to:
  /// **'You don’t have permission to change this file or its folder. Save it somewhere else, or ask the owner for access. Your edits are kept.'**
  String get saveFailedPermission;

  /// Save failure dialog (a11-7d): another app locks the file.
  ///
  /// In en, this message translates to:
  /// **'Another app has the file open and locked. Close it there and try again, or save a copy somewhere else. Your edits are kept.'**
  String get saveFailedLocked;

  /// Save failure dialog (a11-7d): the new file could not replace the original.
  ///
  /// In en, this message translates to:
  /// **'Ferman wrote your changes to a temporary file but couldn’t put it in place of the original. The original is unchanged and your edits are kept.'**
  String get saveFailedRename;

  /// Save failure dialog (a11-7d): the drive went away during the save.
  ///
  /// In en, this message translates to:
  /// **'The drive with this file is no longer connected. Reconnect it and try again, or save somewhere else. Your edits are kept.'**
  String get saveFailedVolume;

  /// Save failure dialog (G40): the file has other hard links.
  ///
  /// In en, this message translates to:
  /// **'This file has other links to it, which replacing it would break. Save it somewhere else. Your edits are kept.'**
  String get saveFailedHardLinked;

  /// Save failure dialog (G40): the file belongs to another user.
  ///
  /// In en, this message translates to:
  /// **'This file belongs to someone else, and Ferman couldn’t keep its owner. Save it somewhere else. Your edits are kept.'**
  String get saveFailedNotOwner;

  /// Save failure dialog: any other failure.
  ///
  /// In en, this message translates to:
  /// **'Ferman couldn’t write the file. Try again, or save somewhere else. Your edits are kept.'**
  String get saveFailedOther;

  /// After a11-7's and a11-7d's message when the recovery copy could not be written either (ARCHITECTURE §7.8, G40): the board's reassurance would not be true.
  ///
  /// In en, this message translates to:
  /// **'No recovery copy exists: Ferman couldn’t write one either, so until you save, these edits are only in this window.'**
  String get saveFailedNoRecoveryCopy;

  /// Save failure dialog (a11-7d): saves again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get saveTryAgain;

  /// Save failure dialog (a11-7): opens Save as when the disk is full.
  ///
  /// In en, this message translates to:
  /// **'Save somewhere else…'**
  String get saveSomewhereElse;

  /// Save failure dialog (a11-7d) and toast (f4): opens Save as.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get saveAsEllipsis;

  /// Toast (f4): the message after a save failed on a full disk.
  ///
  /// In en, this message translates to:
  /// **'The disk is full. Free some space or save somewhere else.'**
  String get saveToastDiskFull;

  /// Toast (f4): the message after any other failed save.
  ///
  /// In en, this message translates to:
  /// **'Your edits are kept. Try again, or save somewhere else.'**
  String get saveToastOther;

  /// Toast (f4): the name of the close button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get saveToastDismiss;

  /// Bar (a11-7b): another app changed the open file. {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'“{name}” changed on disk.'**
  String fileChangedTitle(String name);

  /// Bar (a11-7b): the sentence under the title.
  ///
  /// In en, this message translates to:
  /// **'Another app or a sync service changed it while it was open. Reload it, keep your version, or compare first.'**
  String get fileChangedBody;

  /// Bar (a11-7b): compare the two versions (disabled until Compare ships).
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get fileChangedCompare;

  /// Bar (a11-7b): saves over the change.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get fileChangedKeepMine;

  /// Bar (a11-7b): drops the edits and opens the file again.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get fileChangedReload;

  /// Warning before Optimize and clean breaks signatures (G35). {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Optimize and clean “{name}”?'**
  String optimizeTitle(String name);

  /// Warning before Optimize and clean (G35): what happens to the signatures.
  ///
  /// In en, this message translates to:
  /// **'Ferman rewrites the whole file without its earlier versions. Its signatures will no longer be valid.'**
  String get optimizeSignedBody;

  /// Warning before Optimize and clean: the button that rewrites the file.
  ///
  /// In en, this message translates to:
  /// **'Optimize and clean'**
  String get optimizeAction;

  /// Save as sheet on Windows: the error under a file name with a character Windows reserves.
  ///
  /// In en, this message translates to:
  /// **'A file name can’t contain any of these: / \\ : * ? \" < > |'**
  String get saveAsNameInvalidWindows;

  /// Save as sheet: the error when the chosen file is the file of another open tab, which saving over would pull from under it.
  ///
  /// In en, this message translates to:
  /// **'This file is open in another tab. Close it there, or choose another name.'**
  String get saveAsNameOpen;

  /// Save as sheet (a1-11): the line under Save as a copy while Where is the document's own folder. {name} is the open file's name.
  ///
  /// In en, this message translates to:
  /// **'“{name}” stays open and unchanged; the copy is saved alongside it.'**
  String saveAsCopyDescriptionHere(String name);

  /// a1-9d: the banner's title on a file no one may write.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is read-only.'**
  String readOnlyFileTitle(String name);

  /// a1-9d: the banner's text.
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t save changes to this file. To keep your changes, save a copy.'**
  String get readOnlyFileBody;

  /// a1-9d: the banner's button, which opens the Save as sheet with Save as a copy checked.
  ///
  /// In en, this message translates to:
  /// **'Save a copy…'**
  String get readOnlyFileSaveCopy;

  /// a1-10b: the question.
  ///
  /// In en, this message translates to:
  /// **'Save changes to “{name}”?'**
  String closeUnsavedTitle(String name);

  /// a1-10b: what is lost; {edits} is closingEdits.
  ///
  /// In en, this message translates to:
  /// **'If you don’t save, your {edits} from this session will be lost.'**
  String closeUnsavedBody(String edits);

  /// a1-10b, a1-12, a11-7e: how many edits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 edit} other{{formatted} edits}}'**
  String closingEdits(int count, String formatted);

  /// a1-10b: the default button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get closeUnsavedSave;

  /// a1-10b: closes without saving; the recovery copy goes.
  ///
  /// In en, this message translates to:
  /// **'Don’t save'**
  String get closeUnsavedDiscard;

  /// a11-7e: the question, for two documents or more.
  ///
  /// In en, this message translates to:
  /// **'Save changes to {count, plural, other{{formatted} documents}} before quitting?'**
  String quitReviewTitle(int count, String formatted);

  /// a11-7e.
  ///
  /// In en, this message translates to:
  /// **'Ferman saves the checked documents, then quits. Changes to unchecked documents are lost.'**
  String get quitReviewBody;

  /// a11-7e.
  ///
  /// In en, this message translates to:
  /// **'Save and quit'**
  String get quitReviewSave;

  /// a11-7e.
  ///
  /// In en, this message translates to:
  /// **'Quit without saving'**
  String get quitReviewDiscard;

  /// a1-12: the title.
  ///
  /// In en, this message translates to:
  /// **'Ferman restored {count, plural, =1{1 document} other{{formatted} documents}}'**
  String recoveryTitle(int count, String formatted);

  /// a1-12, without the board’s time, which the engine does not know (G40).
  ///
  /// In en, this message translates to:
  /// **'Ferman closed unexpectedly. These documents had unsaved changes, and Ferman had kept a copy of each on this device.'**
  String get recoveryBody;

  /// a1-12: under the list.
  ///
  /// In en, this message translates to:
  /// **'Restored documents open as unsaved; the files on disk haven’t changed. Nothing was sent anywhere.'**
  String get recoveryNote;

  /// a1-12: deletes every copy.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get recoveryDiscard;

  /// a1-12: the default button; counts the checked rows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Open 1 document} other{Open {formatted} documents}}'**
  String recoveryOpen(int count, String formatted);

  /// a11-7f: the badge of a row whose original changed.
  ///
  /// In en, this message translates to:
  /// **'Changed on disk'**
  String get recoveryChangedBadge;

  /// a11-7f, without the board’s time and name, which the engine gives only once it opens (G40).
  ///
  /// In en, this message translates to:
  /// **'The file on disk changed after Ferman’s copy. The restored version opens under a new name, so neither is overwritten.'**
  String get recoveryChangedBody;

  /// a11-7f: the word in brackets in a restored document's new file name, “e-Arşiv fatura 4187 (recovered).pdf”. No slashes.
  ///
  /// In en, this message translates to:
  /// **'recovered'**
  String get recoveryFileSuffix;

  /// a3-16a: the question.
  ///
  /// In en, this message translates to:
  /// **'Edit a signed document?'**
  String get signedTitle;

  /// a3-16a: one signature whose signer and date the file gives.
  ///
  /// In en, this message translates to:
  /// **'“{name}” has 1 signature, by {signer} on {date}. Any change to the document makes that signature invalid.'**
  String signedBodyBy(String name, String signer, String date);

  /// a3-16a: any other number of signatures, or no name or date in the file.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{“{name}” has 1 signature. Any change to the document makes that signature invalid.} other{“{name}” has {formatted} signatures. Any change to the document makes those signatures invalid.}}'**
  String signedBody(String name, int count, String formatted);

  /// a3-16a: the default button.
  ///
  /// In en, this message translates to:
  /// **'Edit a copy'**
  String get signedEditCopy;

  /// a3-16a.
  ///
  /// In en, this message translates to:
  /// **'Edit anyway'**
  String get signedEditAnyway;

  /// a3-16a: under the question.
  ///
  /// In en, this message translates to:
  /// **'The copy opens in a new tab as “{name}”. The signed original stays as it is.'**
  String signedCopyHint(String name);

  /// a3-16a: the copy’s file name without its extension.
  ///
  /// In en, this message translates to:
  /// **'{stem} (copy)'**
  String signedCopyName(String stem);

  /// a3-16a: the same, when that name is taken; {number} is 2 or more.
  ///
  /// In en, this message translates to:
  /// **'{stem} (copy {number})'**
  String signedCopyNameNumbered(String stem, int number);

  /// a3-16b: the bar after Edit anyway.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The signature in this document is no longer valid.} other{The signatures in this document are no longer valid.}}'**
  String signedBannerTitle(int count);

  /// a3-16b: one signer the file names.
  ///
  /// In en, this message translates to:
  /// **'You changed the document after {signer} signed it. Saving keeps the signature, but it will show as invalid.'**
  String signedBannerBodyBy(String signer);

  /// a3-16b: otherwise.
  ///
  /// In en, this message translates to:
  /// **'You changed the document after it was signed. Saving keeps the signatures, but they will show as invalid.'**
  String get signedBannerBody;

  /// a3-16b: the bar’s button.
  ///
  /// In en, this message translates to:
  /// **'Review edits'**
  String get signedBannerReview;

  /// a3-12: the signature row, at the top of the review list.
  ///
  /// In en, this message translates to:
  /// **'{signer}’s signature is no longer valid'**
  String signedReviewRow(String signer);

  /// a3-12: the same without one named signer.
  ///
  /// In en, this message translates to:
  /// **'The signatures are no longer valid'**
  String get signedReviewRowOther;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Mark edited text'**
  String get settingsEditMarks;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Shown only in Ferman while you edit. Never saved into the file or printed.'**
  String get settingsEditMarksNote;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'When a font is missing a character'**
  String get settingsMissingGlyphs;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Use a similar font and say so'**
  String get settingsMissingGlyphsSimilar;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Ask each time'**
  String get settingsMissingGlyphsAsk;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Keep the original font and mark the character'**
  String get settingsMissingGlyphsMark;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Font for new text'**
  String get settingsFontForNewText;

  /// a11-1c: the option shown, while Add text waits (B042).
  ///
  /// In en, this message translates to:
  /// **'Match surrounding text'**
  String get settingsFontForNewTextMatch;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Keep versions'**
  String get settingsKeepVersions;

  /// a11-1c: the option that keeps a version at each save, for 30 days in the app data directory (ADR 0022; the board says next to the file).
  ///
  /// In en, this message translates to:
  /// **'Kept for 30 days'**
  String get settingsKeepVersions30;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Let paragraphs reflow inside their frame while typing'**
  String get settingsReflow;

  /// a11-1c: the switch the engine follows.
  ///
  /// In en, this message translates to:
  /// **'Save a recovery copy every minute'**
  String get settingsRecoveryCopies;

  /// a11-1c: the group of G43.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get settingsSaving;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Changes are added to the end of the file'**
  String get settingsSavingEnd;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Saving stays fast, and signatures made before your changes stay intact. Ferman rewrites the whole file only when you choose Optimize and clean.'**
  String get settingsSavingEndBody;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Optimize and clean'**
  String get settingsOptimize;

  /// a11-1c.
  ///
  /// In en, this message translates to:
  /// **'Rewrites the whole file to make it smaller. Run it from the command palette; it’s never used on its own, and Ferman warns you first if signatures would become invalid.'**
  String get settingsOptimizeBody;

  /// a11-1c: above the folder.
  ///
  /// In en, this message translates to:
  /// **'Recovery copies'**
  String get settingsRecoveryFolder;

  /// View row: what a screen reader says the zoom field takes (a2-2, B127). {min} and {max} are percentages already written for the region.
  ///
  /// In en, this message translates to:
  /// **'Type a zoom from {min} to {max}'**
  String shellZoomTypeHint(String min, String max);

  /// Tooltip of the Edit tab and the Edit text tool on a document whose permissions forbid changes (a2-10a rTip, G27).
  ///
  /// In en, this message translates to:
  /// **'The author doesn’t allow editing'**
  String get shellEditForbidden;

  /// Edit panel (a3-1a): the first tip.
  ///
  /// In en, this message translates to:
  /// **'Click any text to select its block. Click again to place the caret.'**
  String get editPanelTipClick;

  /// Edit panel (a3-1a): the second tip. {key} is the key cap of Option or Alt, drawn as a key.
  ///
  /// In en, this message translates to:
  /// **'Tab moves between blocks; Enter starts editing. Hold {key} to show every block.'**
  String editPanelTipKeys(String key);

  /// Edit panel (a3-1a): after the badge with the number of edits, as in "3 edits in this session".
  ///
  /// In en, this message translates to:
  /// **'in this session'**
  String get editPanelInSession;

  /// Edit panel (a3-1a): the button that opens the list of edits, after their number.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get editPanelReview;

  /// The German language, named in the interface language: the Language select of the Edit panel (a3-14, FmEditPanel langs).
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageNameGerman;

  /// The Japanese language, named in the interface language: the Language select of the Edit panel (a3-14, FmEditPanel langs).
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageNameJapanese;

  /// A text block's language with its region, in the status bar (a3-14: "English (United Kingdom)").
  ///
  /// In en, this message translates to:
  /// **'{language} ({region})'**
  String languageWithRegion(String language, String region);

  /// Edit panel: title of the section with the language of the block being edited, and the name of its select (a3-14, FmEditPanel t.lang).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get editLanguage;

  /// Edit panel, Language section: the switch that spell-checks the block (a3-14, FmEditPanel t.spell).
  ///
  /// In en, this message translates to:
  /// **'Check spelling'**
  String get editCheckSpelling;

  /// Edit panel, Language section: the switch that hyphenates the block (a3-14, FmEditPanel t.hyph).
  ///
  /// In en, this message translates to:
  /// **'Hyphenate'**
  String get editHyphenate;

  /// Edit mode: the name of a history step that changed only the language of a block, in the Undo history panel (a3-10). {page} is the page number, formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Changed language · page {page}'**
  String editStepLanguage(String page);

  /// a3-12: the panel’s close button.
  ///
  /// In en, this message translates to:
  /// **'Close review'**
  String get reviewClose;

  /// a3-12: the filter’s accessible name.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get reviewShow;

  /// a3-12: filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reviewFilterAll;

  /// a3-12: filter.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get reviewFilterText;

  /// a3-12: filter.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get reviewFilterFonts;

  /// a3-12: filter.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get reviewFilterWarnings;

  /// a3-12b: the empty list.
  ///
  /// In en, this message translates to:
  /// **'No edits yet'**
  String get reviewEmptyTitle;

  /// a3-12b: the empty list.
  ///
  /// In en, this message translates to:
  /// **'Changes you make in this session appear here. The list clears when you close the document; earlier sessions are in Version history.'**
  String get reviewEmptyBody;

  /// a3-12b: why Revert all and Export list are disabled.
  ///
  /// In en, this message translates to:
  /// **'No edits yet'**
  String get reviewNothing;

  /// a3-12: footer.
  ///
  /// In en, this message translates to:
  /// **'Revert all…'**
  String get reviewRevertAll;

  /// a3-12: footer.
  ///
  /// In en, this message translates to:
  /// **'Export list…'**
  String get reviewExportList;

  /// a3-12: a row’s button.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get reviewGoTo;

  /// a3-12: a row’s button.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get reviewRevert;

  /// a3-10: the history step of a revert from the review list.
  ///
  /// In en, this message translates to:
  /// **'Reverted an edit'**
  String get reviewStepReverted;

  /// a3-10: the history step of Revert all.
  ///
  /// In en, this message translates to:
  /// **'Reverted all edits'**
  String get reviewStepRevertedAll;

  /// a3-12: where the signature row is when several signatures on different pages are gone.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get reviewWhereSignature;

  /// a3-12: where the signature row is, with one signer. {page} is formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Page {page} · signature'**
  String reviewWhereSignaturePage(String page);

  /// a3-12: where a row is. {page} is formatted for the region. The block has no name (G125).
  ///
  /// In en, this message translates to:
  /// **'Page {page} · text'**
  String reviewWhereText(String page);

  /// a3-12: where a row is.
  ///
  /// In en, this message translates to:
  /// **'Page {page} · font'**
  String reviewWhereFont(String page);

  /// a3-12: where a row is.
  ///
  /// In en, this message translates to:
  /// **'Page {page} · kept warning'**
  String reviewWhereWarning(String page);

  /// a3-12: the file name Export list suggests, without its extension.
  ///
  /// In en, this message translates to:
  /// **'{name} edits'**
  String reviewExportName(String name);

  /// a3-12: Export list failed.
  ///
  /// In en, this message translates to:
  /// **'The list couldn’t be saved.'**
  String get reviewExportFailed;

  /// a3-12b: Revert all’s question. The board also names the time it opened, which the app does not keep.
  ///
  /// In en, this message translates to:
  /// **'“{name}” goes back to how it was when you opened it. Undo brings the edits back until you close the document.'**
  String reviewRevertAllBody(String name);

  /// a3-12b: an edit a later edit depends on (G42).
  ///
  /// In en, this message translates to:
  /// **'“{later}” was typed into the sentence after this change. Reverting “{change}” removes it too.'**
  String reviewDependentBody(String later, String change);

  /// a3-12b: the same with several later edits, always two or more. {shown} is {count} formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{shown} later edits build on this change. Reverting “{change}” removes them too.}}'**
  String reviewDependentsBody(int count, String shown, String change);

  /// a3-12: a kept warning’s row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{shown} line hidden — overflow kept} other{{shown} lines hidden — overflow kept}}'**
  String reviewKeptWarning(int count, String shown);

  /// a3-12b.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Revert the edit?} other{Revert all {shown} edits?}}'**
  String reviewRevertAllTitle(int count, String shown);

  /// a3-12b.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Revert {shown} edit} other{Revert {shown} edits}}'**
  String reviewRevertAllButton(int count, String shown);

  /// a3-12b (G42).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Also revert the edit that depends on it?} other{Also revert the {shown} edits that depend on it?}}'**
  String reviewDependentTitle(int count, String shown);

  /// a3-12b (G42). {shown} counts the edit asked about too.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Revert both} other{Revert all {shown}}}'**
  String reviewDependentButton(int count, String shown);

  /// a3-2 (FmEditPanel t.title): the title of the right panel while a block is edited.
  ///
  /// In en, this message translates to:
  /// **'Text block'**
  String get editPanelTitle;

  /// a3-2: section.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get editPanelText;

  /// a3-2: the font size field's screen-reader name.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get editPanelSize;

  /// a3-2: the colour popover's screen-reader name.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get editPanelColour;

  /// a3-2: colours section of the colour popover.
  ///
  /// In en, this message translates to:
  /// **'In this document'**
  String get editPanelColoursDocument;

  /// a3-2: colours section of the colour popover.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get editPanelColoursStandard;

  /// a3-2: fonts section of the font popover.
  ///
  /// In en, this message translates to:
  /// **'In this document'**
  String get editPanelFontsDocument;

  /// a3-2: fonts section of the font popover.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get editPanelFontsDevice;

  /// a3-2: button.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get editPanelBold;

  /// a3-2: button.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get editPanelItalic;

  /// a3-2: button.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get editPanelUnderline;

  /// a3-2: why Bold is disabled; bold is never faked.
  ///
  /// In en, this message translates to:
  /// **'This font has no other weight on this computer that can draw this text.'**
  String get editPanelNoBold;

  /// a3-2: why Italic is disabled; italic is never faked.
  ///
  /// In en, this message translates to:
  /// **'This font has no italic on this computer that can draw this text.'**
  String get editPanelNoItalic;

  /// a3-2: why Underline is disabled.
  ///
  /// In en, this message translates to:
  /// **'A PDF font has no underline to switch to, and Ferman does not draw a false one.'**
  String get editPanelNoUnderline;

  /// a3-2: the alignment group's screen-reader name.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get editPanelAlignment;

  /// a3-2: segment.
  ///
  /// In en, this message translates to:
  /// **'Align left'**
  String get editPanelAlignLeft;

  /// a3-2: segment.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get editPanelAlignCenter;

  /// a3-2: segment.
  ///
  /// In en, this message translates to:
  /// **'Align right'**
  String get editPanelAlignRight;

  /// a3-2: segment.
  ///
  /// In en, this message translates to:
  /// **'Justify'**
  String get editPanelAlignJustify;

  /// a3-2: section.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get editPanelSpacing;

  /// a3-2: spacing between characters.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get editPanelCharacter;

  /// a3-2: spacing between lines.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get editPanelLine;

  /// a3-2: spacing before the block.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get editPanelBefore;

  /// a3-2: spacing after the block.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get editPanelAfter;

  /// a3-2: section.
  ///
  /// In en, this message translates to:
  /// **'Position and size'**
  String get editPanelPosition;

  /// a3-2: field.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get editPanelWidth;

  /// a3-2: field.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get editPanelHeight;

  /// a3-2: button in the heading.
  ///
  /// In en, this message translates to:
  /// **'Reset text style'**
  String get editPanelReset;

  /// a3-2: the note at the panel's end.
  ///
  /// In en, this message translates to:
  /// **'Text reflows inside the frame. Drag a handle to resize it.'**
  String get editPanelHint;

  /// a3-1c: the accessible name of the floating format bar.
  ///
  /// In en, this message translates to:
  /// **'Format selection'**
  String get editBarLabel;

  /// a3-1c: button; a3-6: the panel's + button.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get editBarLink;

  /// a3-1c: button, disabled until comments work.
  ///
  /// In en, this message translates to:
  /// **'Highlight (adds a comment)'**
  String get editBarHighlight;

  /// a3-1c: button, disabled until comments work.
  ///
  /// In en, this message translates to:
  /// **'Comment on selection'**
  String get editBarComment;

  /// a3-1c: button, disabled until find and replace works.
  ///
  /// In en, this message translates to:
  /// **'Find and replace these words'**
  String get editBarReplace;

  /// a3-10: the name of a history step: a change in the text panel (a3-2) or a handle's drag. {page} is the page number, formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Changed text style · page {page}'**
  String editStepStyle(String page);

  /// a3-10: the name of a history step: a change in the text panel (a3-2) or a handle's drag. {page} is the page number, formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Moved text block · page {page}'**
  String editStepMoved(String page);

  /// a3-10: the name of a history step: a change in the text panel (a3-2) or a handle's drag. {page} is the page number, formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Resized text block · page {page}'**
  String editStepResized(String page);

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

  /// a11-6b: where a background task is.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String jobPageOf(String page, String pages);

  /// a11-6b: a paused task's place.
  ///
  /// In en, this message translates to:
  /// **'Paused at page {page}'**
  String jobPausedAtPage(String page);

  /// a11-6b: why a background task failed.
  ///
  /// In en, this message translates to:
  /// **'The disk is full. Free some space and try again.'**
  String get jobFailedDiskFull;

  /// a11-6b: the title of a task that copies a document.
  ///
  /// In en, this message translates to:
  /// **'Copying {name}'**
  String jobCopyingTitle(String name);

  /// a11-6b: the title of the finished copy.
  ///
  /// In en, this message translates to:
  /// **'Copied {name}'**
  String jobCopiedTitle(String name);

  /// a11-6b: the title of a failed copy.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t copy {name}'**
  String jobCopyFailedTitle(String name);

  /// a11-6b: the drawer's title and its region's name.
  ///
  /// In en, this message translates to:
  /// **'Background tasks'**
  String get tasksTitle;

  /// a11-6b: the drawer's close button.
  ///
  /// In en, this message translates to:
  /// **'Close drawer'**
  String get tasksClose;

  /// Status bar: screen-reader name of the task line, which opens the drawer.
  ///
  /// In en, this message translates to:
  /// **'Show or hide background tasks'**
  String get tasksOpen;

  /// G49: the empty drawer.
  ///
  /// In en, this message translates to:
  /// **'No background tasks'**
  String get tasksEmptyTitle;

  /// G49: the empty drawer.
  ///
  /// In en, this message translates to:
  /// **'Long work, such as compressing a file, runs here while you keep working.'**
  String get tasksEmptyBody;

  /// Status bar: several background tasks in the one task line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task running} other{{formatted} tasks running}}'**
  String tasksRunning(int count, String formatted);

  /// a11-6b: pauses a task.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get taskPause;

  /// a11-6b: resumes a paused task.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get taskResume;

  /// a11-6b: shows a finished task's file in the file manager.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get taskShow;

  /// a11-6b: takes a finished task's row away.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get taskDismiss;

  /// G49: the question before a running task is cancelled; task is its title.
  ///
  /// In en, this message translates to:
  /// **'Cancel “{task}”?'**
  String taskCancelTitle(String task);

  /// G49: the question before a running task is cancelled.
  ///
  /// In en, this message translates to:
  /// **'Its work so far is discarded, and no file is left behind.'**
  String get taskCancelBody;

  /// G49: leaves the task running.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get taskKeepRunning;

  /// G49: cancels the task.
  ///
  /// In en, this message translates to:
  /// **'Cancel task'**
  String get taskCancelConfirm;

  /// Quitting with background tasks running: the question.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A background task is still running} other{{formatted} background tasks are still running}}'**
  String tasksQuitTitle(int count, String formatted);

  /// Quitting with background tasks running.
  ///
  /// In en, this message translates to:
  /// **'Quitting cancels them, and they leave no partial files.'**
  String get tasksQuitBody;

  /// Quitting with background tasks running: stays in the app.
  ///
  /// In en, this message translates to:
  /// **'Keep working'**
  String get tasksQuitKeep;

  /// Quitting with background tasks running: goes on.
  ///
  /// In en, this message translates to:
  /// **'Cancel tasks and quit'**
  String get tasksQuitConfirm;

  /// Organize (a6-1): the screen-reader name of the page grid.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get organizeGridLabel;

  /// Organize (a6-1): the screen-reader name of the right panel.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get organizePanelLabel;

  /// Organize tool row (a6-1): the hint with a selection. {selected} and {pages} are written for the region; {total} picks the plural form.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{selected} of {pages} page selected} other{{selected} of {pages} pages selected}}'**
  String organizeHintSelected(int total, String selected, String pages);

  /// Organize tool row (a6-1b): the hint during a drag.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moving {n} page} other{Moving {n} pages}}'**
  String organizeHintMoving(int count, String n);

  /// Organize panel (a6-1): the heading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page selected} other{{n} pages selected}}'**
  String organizePanelTitle(int count, String n);

  /// Organize panel (a6-1): the section, and its first row's name.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get organizePanelPages;

  /// Organize panel (a6-1): the selected pages' numbers and their page labels.
  ///
  /// In en, this message translates to:
  /// **'{pages} (labels {labels})'**
  String organizePanelPagesLabels(String pages, String labels);

  /// Organize panel (a6-1): the row with the pages' size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get organizePanelSize;

  /// Organize panel (a6-1): the row with the pages' rotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get organizePanelRotation;

  /// Organize panel: pages of the selection differ in this value; not drawn.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get organizePanelMixed;

  /// Organize panel (a6-1): the section of commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get organizePanelCommands;

  /// Organize panel (a6-1): opens Extract.
  ///
  /// In en, this message translates to:
  /// **'Extract…'**
  String get organizePanelExtract;

  /// Organize panel (a6-1): opens Replace.
  ///
  /// In en, this message translates to:
  /// **'Replace…'**
  String get organizePanelReplace;

  /// Organize panel (a6-1): the section. {page} is the last selected page's number.
  ///
  /// In en, this message translates to:
  /// **'Insert after page {page}'**
  String organizePanelInsertAfter(String page);

  /// Organize panel (a6-1): inserts a blank page.
  ///
  /// In en, this message translates to:
  /// **'Blank page'**
  String get organizePanelBlankPage;

  /// Organize panel (a6-1): inserts pages from a file.
  ///
  /// In en, this message translates to:
  /// **'Pages from a file…'**
  String get organizePanelFromFile;

  /// Organize panel (a6-1): inserts pages from a scanner or camera.
  ///
  /// In en, this message translates to:
  /// **'From scanner or camera…'**
  String get organizePanelFromScanner;

  /// Organize's page menu (a6-1): its heading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page} other{{n} pages}}'**
  String organizePagesCount(int count, String n);

  /// Organize's page menu (a6-1).
  ///
  /// In en, this message translates to:
  /// **'Extract as new PDF…'**
  String get organizeMenuExtract;

  /// Organize's page menu (a6-1).
  ///
  /// In en, this message translates to:
  /// **'Insert blank page after'**
  String get organizeMenuInsertBlank;

  /// Organize's page menu (a6-1).
  ///
  /// In en, this message translates to:
  /// **'Insert pages from file…'**
  String get organizeMenuInsertFile;

  /// Organize's page menu (a6-1).
  ///
  /// In en, this message translates to:
  /// **'Replace with pages from file…'**
  String get organizeMenuReplace;

  /// Organize's page menu (a6-1).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete {n} page} other{Delete {n} pages}}'**
  String organizeMenuDelete(int count, String n);

  /// Organize: why Delete is disabled with every page selected; not drawn.
  ///
  /// In en, this message translates to:
  /// **'A document keeps at least one page'**
  String get organizeDeleteAllReason;

  /// Toast (a11-6) and history step: after deleting pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page deleted} other{{n} pages deleted}}'**
  String organizeToastDeleted(int count, String n);

  /// Toast and history step: after rotating pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page rotated} other{{n} pages rotated}}'**
  String organizeToastRotated(int count, String n);

  /// Toast and history step: after duplicating pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page duplicated} other{{n} pages duplicated}}'**
  String organizeToastDuplicated(int count, String n);

  /// Toast (a6-1b) and history step: after moving pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page moved} other{{n} pages moved}}'**
  String organizeToastMoved(int count, String n);

  /// Toast: after a drop on the page grid inserted a file's pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} page inserted} other{{n} pages inserted}}'**
  String organizeToastInserted(int count, String n);

  /// Toast (a11-6): the pages a command acted on, such as 4–6.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Page {pages}} other{Pages {pages}}}'**
  String organizeToastPages(int count, String pages);

  /// Toast after deleting pages (M4 plan question 5): {pages} is organizeToastPages. Say that the content remains recoverable from the file. Use the names of Save as's Remove edit history and of Optimize and clean.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{pages}. It stays in the file until you save with Remove edit history or run Optimize and clean.} other{{pages}. They stay in the file until you save with Remove edit history or run Optimize and clean.}}'**
  String organizeToastDeletedNote(int count, String pages);

  /// History step: inserted the file {name}.
  ///
  /// In en, this message translates to:
  /// **'Insert {name}'**
  String organizeStepInsert(String name);

  /// Toast: a page command failed; the document is as it was.
  ///
  /// In en, this message translates to:
  /// **'The pages weren’t changed'**
  String get organizeFailed;

  /// Toast: a dropped file's pages could not go in.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t insert {name}'**
  String organizeInsertFailed(String name);

  /// Page grid (a6-1b): what a drop does.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Drop to move page {pages} before page {before}} other{Drop to move pages {pages} before page {before}}}'**
  String organizeDropMoveBefore(int count, String pages, String before);

  /// Page grid (a6-1b): what a drop past the last page does.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Drop to move page {pages} to the end} other{Drop to move pages {pages} to the end}}'**
  String organizeDropMoveEnd(int count, String pages);

  /// Page grid: files over the grid (G105), what a drop does.
  ///
  /// In en, this message translates to:
  /// **'Drop to insert before page {before}'**
  String organizeDropFilesBefore(String before);

  /// Page grid: files over the grid past the last page (G105).
  ///
  /// In en, this message translates to:
  /// **'Drop to insert at the end'**
  String get organizeDropFilesEnd;

  /// a11-6b: an insert running, from a dialog or a drop.
  ///
  /// In en, this message translates to:
  /// **'Reading pages from {name}'**
  String jobInsertingTitle(String name);

  /// a11-6b: an insert finished, from a dialog or a drop.
  ///
  /// In en, this message translates to:
  /// **'Inserted pages from {name}'**
  String jobInsertedTitle(String name);

  /// Organize tool row: why a command on the selection is disabled while none is selected; not drawn.
  ///
  /// In en, this message translates to:
  /// **'Select pages first'**
  String get organizeSelectFirst;

  /// Organize's dialogs and crop panel: closes without changing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get organizeCancel;

  /// Toast title: the engine refused a page operation.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the pages'**
  String get organizeFailedTitle;

  /// Error under a page range field. {last} is the last page's number.
  ///
  /// In en, this message translates to:
  /// **'Write pages like 1–3, 5, up to page {last}.'**
  String organizeBadRange(String last);

  /// a6-4 and G45: a page size option. {size} is formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'A4 · {size}'**
  String organizeSizeA4(String size);

  /// a6-4 and G45: a page size option. {size} is formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Letter · {size}'**
  String organizeSizeLetter(String size);

  /// a6-4 and G45: a page size option that shows width and height.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get organizeSizeCustom;

  /// A custom page size's width field.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get organizeWidth;

  /// A custom page size's height field.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get organizeHeight;

  /// a6-4: the panel's title.
  ///
  /// In en, this message translates to:
  /// **'Crop and page size'**
  String get cropTitle;

  /// a6-4: panel section.
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get cropMargins;

  /// a6-4: margin field.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get cropTop;

  /// a6-4: margin field.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get cropBottom;

  /// a6-4: margin field; the page's left, which never mirrors.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get cropLeft;

  /// a6-4: margin field; the page's right, which never mirrors.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get cropRight;

  /// a6-4: finds the content box of each page.
  ///
  /// In en, this message translates to:
  /// **'Remove white margins'**
  String get cropRemoveWhite;

  /// a6-4, not drawn: Remove white margins found nothing.
  ///
  /// In en, this message translates to:
  /// **'These pages have no content to measure.'**
  String get cropNoContent;

  /// a6-4, not drawn: the margins are larger than a page in the scope.
  ///
  /// In en, this message translates to:
  /// **'These margins leave nothing of page {page}.'**
  String cropTooMuch(String page);

  /// a6-4: panel section and its select's name.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get cropPageSize;

  /// a6-4: the first page size option.
  ///
  /// In en, this message translates to:
  /// **'Keep current size ({size})'**
  String cropKeepSize(String size);

  /// a6-4: the accessible name of the Centre or Scale to fit control.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get cropContent;

  /// a6-4: content stays at its size, centred.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get cropFitCentre;

  /// a6-4: content is scaled to the new page.
  ///
  /// In en, this message translates to:
  /// **'Scale to fit'**
  String get cropFitScale;

  /// a6-4: panel section.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get cropApplyTo;

  /// a6-4: scope.
  ///
  /// In en, this message translates to:
  /// **'This page'**
  String get cropThisPage;

  /// a6-4: scope, every page of the document.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The only page} other{All {formatted} pages}}'**
  String cropAllPages(int count, String formatted);

  /// a6-4: scope, the pages of a range.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get cropSomePages;

  /// a6-4: the accessible name of the parity select.
  ///
  /// In en, this message translates to:
  /// **'Which pages'**
  String get cropWhichPages;

  /// a6-4: parity option.
  ///
  /// In en, this message translates to:
  /// **'All pages in range'**
  String get cropParityAll;

  /// a6-4: parity option.
  ///
  /// In en, this message translates to:
  /// **'Odd pages'**
  String get cropParityOdd;

  /// a6-4: parity option.
  ///
  /// In en, this message translates to:
  /// **'Even pages'**
  String get cropParityEven;

  /// a6-4: the primary button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Crop {formatted} page} other{Crop {formatted} pages}}'**
  String cropAction(int count, String formatted);

  /// a6-4: the primary button when only the page size changes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Resize {formatted} page} other{Resize {formatted} pages}}'**
  String cropResizeAction(int count, String formatted);

  /// The toast after a crop (a11-6's pattern).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} page cropped} other{{formatted} pages cropped}}'**
  String cropDone(int count, String formatted);

  /// The toast after a crop: cropping hides content and does not remove it (G57).
  ///
  /// In en, this message translates to:
  /// **'What’s outside is hidden, not removed.'**
  String get cropDoneHidden;

  /// The history step of a crop.
  ///
  /// In en, this message translates to:
  /// **'Crop pages'**
  String get cropStep;

  /// The history step of a new page size.
  ///
  /// In en, this message translates to:
  /// **'Change page size'**
  String get cropSizeStep;

  /// a6-5: the dialog's title.
  ///
  /// In en, this message translates to:
  /// **'Page labels'**
  String get labelsTitle;

  /// a6-5: the dialog's description.
  ///
  /// In en, this message translates to:
  /// **'Choose how pages are numbered in Ferman, in other PDF apps and when printing.'**
  String get labelsDescription;

  /// a6-5: column head, shown in capitals, and the field's name.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get labelsColumnPages;

  /// a6-5: column head, shown in capitals, and the select's name.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get labelsColumnStyle;

  /// a6-5: column head, shown in capitals, and the field's name.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get labelsColumnPrefix;

  /// a6-5: column head, shown in capitals, and the field's name.
  ///
  /// In en, this message translates to:
  /// **'Start at'**
  String get labelsColumnStart;

  /// a6-5: the empty prefix's placeholder.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get labelsPrefixNone;

  /// a6-5: a label style.
  ///
  /// In en, this message translates to:
  /// **'i, ii, iii'**
  String get labelsStyleRomanLower;

  /// a6-5: a label style.
  ///
  /// In en, this message translates to:
  /// **'I, II, III'**
  String get labelsStyleRomanUpper;

  /// a6-5: a label style.
  ///
  /// In en, this message translates to:
  /// **'1, 2, 3'**
  String get labelsStyleDecimal;

  /// a6-5: a label style.
  ///
  /// In en, this message translates to:
  /// **'a, b, c'**
  String get labelsStyleLettersLower;

  /// A label style a6-5 does not draw, which PDF has.
  ///
  /// In en, this message translates to:
  /// **'A, B, C'**
  String get labelsStyleLettersUpper;

  /// a6-5: a label style with no number.
  ///
  /// In en, this message translates to:
  /// **'Prefix only'**
  String get labelsStyleNone;

  /// a6-5: a row's remove button.
  ///
  /// In en, this message translates to:
  /// **'Remove range'**
  String get labelsRemoveRange;

  /// a6-5: adds a row.
  ///
  /// In en, this message translates to:
  /// **'Add range'**
  String get labelsAddRange;

  /// a6-5: the preview row's caption.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get labelsPreview;

  /// a6-5: disabled until page marks ship.
  ///
  /// In en, this message translates to:
  /// **'Also print the numbers on the pages'**
  String get labelsPrint;

  /// a6-5: the note under the disabled checkbox.
  ///
  /// In en, this message translates to:
  /// **'Adds them as a footer. Pages that already show a number are skipped.'**
  String get labelsPrintNote;

  /// a6-5: the primary button.
  ///
  /// In en, this message translates to:
  /// **'Apply labels'**
  String get labelsApply;

  /// The history step of new labels.
  ///
  /// In en, this message translates to:
  /// **'Change page labels'**
  String get labelsStep;

  /// a6-5, not drawn: a row's pages cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: write its pages like 1–9.'**
  String labelsErrorInvalid(String row);

  /// a6-5, not drawn: ranges overlap or are out of order.
  ///
  /// In en, this message translates to:
  /// **'Row {row} overlaps the range before it.'**
  String labelsErrorOverlap(String row);

  /// a6-5, not drawn: a range past the last page.
  ///
  /// In en, this message translates to:
  /// **'Row {row} goes past the last page, {last}.'**
  String labelsErrorPast(String row, String last);

  /// a6-5, not drawn: a page no range covers.
  ///
  /// In en, this message translates to:
  /// **'Page {page} is in no range. Ranges must cover every page.'**
  String labelsErrorUncovered(String page);

  /// a6-1: Insert's menu.
  ///
  /// In en, this message translates to:
  /// **'Blank page'**
  String get insertMenuBlank;

  /// a6-1: Insert's menu.
  ///
  /// In en, this message translates to:
  /// **'Pages from a file…'**
  String get insertMenuFile;

  /// a6-1: Insert's menu, disabled until scanning ships.
  ///
  /// In en, this message translates to:
  /// **'From scanner or camera…'**
  String get insertMenuScan;

  /// G45: the dialog's title.
  ///
  /// In en, this message translates to:
  /// **'Insert blank page'**
  String get insertBlankTitle;

  /// G45: the size select.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get insertSize;

  /// G45: the first size option.
  ///
  /// In en, this message translates to:
  /// **'Same as page {page} ({size})'**
  String insertSameSize(String page, String size);

  /// G45: the accessible name of Portrait or Landscape.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get insertOrientation;

  /// G45: orientation.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get insertPortrait;

  /// G45: orientation.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get insertLandscape;

  /// G45: the count field.
  ///
  /// In en, this message translates to:
  /// **'Number of pages'**
  String get insertCount;

  /// G45: the accessible name of Before or After.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get insertPosition;

  /// G45: position, before the page in the next field.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get insertBefore;

  /// G45: position, after the page in the next field.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get insertAfter;

  /// G45: the position's page field.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get insertPage;

  /// G45: the primary button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Insert {formatted} page} other{Insert {formatted} pages}}'**
  String insertAction(int count, String formatted);

  /// The history step of blank pages.
  ///
  /// In en, this message translates to:
  /// **'Insert blank page'**
  String get insertBlankStep;

  /// G45: the dialog's title.
  ///
  /// In en, this message translates to:
  /// **'Insert pages from file'**
  String get insertFileTitle;

  /// G45: the primary button.
  ///
  /// In en, this message translates to:
  /// **'Insert pages'**
  String get insertFileAction;

  /// The history step of inserted pages.
  ///
  /// In en, this message translates to:
  /// **'Insert pages from file'**
  String get insertFileStep;

  /// G45: opens the system's file panel.
  ///
  /// In en, this message translates to:
  /// **'Choose file…'**
  String get sourceChoose;

  /// G45: before a file is chosen.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get sourceNone;

  /// G45: the chosen file and its pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name} · {formatted} page} other{{name} · {formatted} pages}}'**
  String sourcePagesInfo(int count, String name, String formatted);

  /// G45: the source's range field.
  ///
  /// In en, this message translates to:
  /// **'Pages from the file'**
  String get sourceRange;

  /// G45 and a6-4: an empty range's placeholder.
  ///
  /// In en, this message translates to:
  /// **'All pages'**
  String get sourceAllPages;

  /// G45: tries the password of a locked source file.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get sourceUnlock;

  /// G45: a source file that forbids assembling.
  ///
  /// In en, this message translates to:
  /// **'This file doesn’t allow taking pages from it. Its owner password lifts that.'**
  String get sourceForbidden;

  /// G45: a source file that cannot be used.
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t read this file.'**
  String get sourceUnreadable;

  /// G45: the dialog's title.
  ///
  /// In en, this message translates to:
  /// **'Replace pages'**
  String get replaceTitle;

  /// G45: the range to replace.
  ///
  /// In en, this message translates to:
  /// **'Pages in this document'**
  String get replaceThese;

  /// G45: fewer new pages than replaced ones.
  ///
  /// In en, this message translates to:
  /// **'The file gives fewer pages: the rest of these pages are deleted.'**
  String get replaceFewer;

  /// G45: more new pages than replaced ones.
  ///
  /// In en, this message translates to:
  /// **'The file gives more pages: the extra ones go after the last.'**
  String get replaceMore;

  /// G45: the primary button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Replace {formatted} page} other{Replace {formatted} pages}}'**
  String replaceAction(int count, String formatted);

  /// The history step of a replace.
  ///
  /// In en, this message translates to:
  /// **'Replace pages'**
  String get replaceStep;

  /// G45: the dialog's title.
  ///
  /// In en, this message translates to:
  /// **'Extract pages'**
  String get extractTitle;

  /// G45: the range to extract.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get extractPages;

  /// G45: extract option.
  ///
  /// In en, this message translates to:
  /// **'One file'**
  String get extractOneFile;

  /// G45: extract option.
  ///
  /// In en, this message translates to:
  /// **'One file per page'**
  String get extractEachFile;

  /// G45: extract option.
  ///
  /// In en, this message translates to:
  /// **'Delete these pages afterwards'**
  String get extractDelete;

  /// G45: why deleting afterwards is off when every page is extracted.
  ///
  /// In en, this message translates to:
  /// **'A document keeps at least one page.'**
  String get extractDeleteAll;

  /// G45: the primary button; a system panel asks where.
  ///
  /// In en, this message translates to:
  /// **'Extract…'**
  String get extractAction;

  /// G45: the name of an extracted file, without its extension.
  ///
  /// In en, this message translates to:
  /// **'{document} pages {pages}'**
  String extractFileName(String document, String pages);

  /// The history step of deleting extracted pages.
  ///
  /// In en, this message translates to:
  /// **'Delete pages'**
  String get extractDeleteStep;

  /// a11-6b: an extract running.
  ///
  /// In en, this message translates to:
  /// **'Extracting pages of {name}'**
  String jobExtractingTitle(String name);

  /// a11-6b: an extract finished.
  ///
  /// In en, this message translates to:
  /// **'Extracted pages of {name}'**
  String jobExtractedTitle(String name);

  /// a11-6b: an extract failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t extract pages of {name}'**
  String jobExtractFailedTitle(String name);

  /// a11-6b: an insert failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t insert pages from {name}'**
  String jobInsertFailedTitle(String name);

  /// a11-6b: a replace running.
  ///
  /// In en, this message translates to:
  /// **'Reading replacement pages from {name}'**
  String jobReplacingTitle(String name);

  /// a11-6b: a replace finished.
  ///
  /// In en, this message translates to:
  /// **'Replaced pages with {name}'**
  String jobReplacedTitle(String name);

  /// a11-6b: a replace failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t replace pages with {name}'**
  String jobReplaceFailedTitle(String name);

  /// a6-2, a6-3: a count of files.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{formatted} files}}'**
  String organizeFileCount(int count, String formatted);

  /// a6-2, a6-3: a count of pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{formatted} pages}}'**
  String organizePageCount(int count, String formatted);

  /// a6-3: the button that adds files.
  ///
  /// In en, this message translates to:
  /// **'Add files…'**
  String get combineAddFiles;

  /// a6-3: the file type in the open panel.
  ///
  /// In en, this message translates to:
  /// **'PDFs, images and Office files'**
  String get combineFilter;

  /// a6-3: the empty list (G29).
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get combineEmptyTitle;

  /// a6-3: the empty list (G29).
  ///
  /// In en, this message translates to:
  /// **'Add PDFs or images to combine them into one new file.'**
  String get combineEmptyBody;

  /// a6-3: the grip of a row.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get combineDrag;

  /// a6-3: a screen reader action on a row.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get combineMoveUp;

  /// a6-3: a screen reader action on a row.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get combineMoveDown;

  /// a6-3: the page range field of a row.
  ///
  /// In en, this message translates to:
  /// **'Pages to include'**
  String get combinePagesToInclude;

  /// a6-3: the page range for every page.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get combineAllPages;

  /// a6-3: the x of a row.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get combineRemoveFile;

  /// a6-3: an image row's second line.
  ///
  /// In en, this message translates to:
  /// **'Image · converted to 1 page'**
  String get combineMetaImage;

  /// a6-3: the second line of a Word or Excel row, which cannot be combined yet (B175).
  ///
  /// In en, this message translates to:
  /// **'Word or Excel'**
  String get combineMetaOffice;

  /// a6-3: a locked row (G45).
  ///
  /// In en, this message translates to:
  /// **'Locked: enter its password to add it.'**
  String get combineNeedsPassword;

  /// a6-3: a locked row after a wrong password (G45).
  ///
  /// In en, this message translates to:
  /// **'That password doesn’t open it. Try again.'**
  String get combineWrongPassword;

  /// a6-3: a row that forbids assembling (M4 plan, question 6).
  ///
  /// In en, this message translates to:
  /// **'This file forbids combining. Enter its owner password to add it.'**
  String get combineOwnerPassword;

  /// a6-3: a row neither a PDF nor an image Ferman can read, or a file that is gone.
  ///
  /// In en, this message translates to:
  /// **'Ferman can’t read this file.'**
  String get combineUnreadable;

  /// a6-3: a row whose page range cannot be used.
  ///
  /// In en, this message translates to:
  /// **'This file doesn’t have those pages.'**
  String get combineBadRange;

  /// a6-3: the password field of a locked row.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get combinePassword;

  /// a6-3: the button of a locked row.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get combineUnlock;

  /// a6-3: a row opened with its password (M4 plan, question 6).
  ///
  /// In en, this message translates to:
  /// **'The new file won’t have this file’s password.'**
  String get combineNotProtected;

  /// a6-3: a signed row (G159).
  ///
  /// In en, this message translates to:
  /// **'Its signatures won’t carry over.'**
  String get combineNotSigned;

  /// a6-3: the output name field.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get combineNewFile;

  /// a6-3: the output name to begin with.
  ///
  /// In en, this message translates to:
  /// **'Combined.pdf'**
  String get combineDefaultName;

  /// a6-3: a checkbox.
  ///
  /// In en, this message translates to:
  /// **'Add a bookmark for each file'**
  String get combineBookmarks;

  /// a6-3: a checkbox; the board's "and signatures" goes (G159).
  ///
  /// In en, this message translates to:
  /// **'Keep form fields'**
  String get combineKeepForms;

  /// a6-3: the note of the checkbox (G159).
  ///
  /// In en, this message translates to:
  /// **'Signatures from the original files don’t carry over.'**
  String get combineKeepFormsNote;

  /// a6-3: the estimated size.
  ///
  /// In en, this message translates to:
  /// **'About {size}'**
  String combineAbout(String size);

  /// a6-3: the primary button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Combine 1 file} other{Combine {formatted} files}}'**
  String combineAction(int count, String formatted);

  /// a6-3: the heading of the result grid.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{RESULT · 1 PAGE} other{RESULT · {formatted} PAGES}}'**
  String combineResult(int count, String formatted);

  /// a6-3: a page of the result for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Page {page}, from file {file}'**
  String combineResultPage(String page, String file);

  /// The toast when a new file's name is taken: a job never overwrites.
  ///
  /// In en, this message translates to:
  /// **'“{name}” already exists. Choose another name.'**
  String combineOutputExists(String name);

  /// a6-2: the title.
  ///
  /// In en, this message translates to:
  /// **'Split “{name}”'**
  String splitTitle(String name);

  /// a6-2: the radio group's name.
  ///
  /// In en, this message translates to:
  /// **'Split by'**
  String get splitBy;

  /// a6-2: a mode.
  ///
  /// In en, this message translates to:
  /// **'Every few pages'**
  String get splitEvery;

  /// a6-2: a mode's line.
  ///
  /// In en, this message translates to:
  /// **'A new file every N pages.'**
  String get splitEveryBody;

  /// a6-2: a mode.
  ///
  /// In en, this message translates to:
  /// **'At top-level bookmarks'**
  String get splitBookmarks;

  /// a6-2: a mode's line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One file per chapter. 1 bookmark found.} other{One file per chapter. {formatted} bookmarks found.}}'**
  String splitBookmarksBody(int count, String formatted);

  /// a6-2: the mode when there are none.
  ///
  /// In en, this message translates to:
  /// **'This document has no bookmarks.'**
  String get splitNoBookmarks;

  /// a6-2: a mode.
  ///
  /// In en, this message translates to:
  /// **'By file size'**
  String get splitSize;

  /// a6-2: a mode's line.
  ///
  /// In en, this message translates to:
  /// **'Files no larger than a size you choose, for e-mail limits.'**
  String get splitSizeBody;

  /// a6-2: a mode.
  ///
  /// In en, this message translates to:
  /// **'At blank pages'**
  String get splitBlank;

  /// a6-2: a mode's line.
  ///
  /// In en, this message translates to:
  /// **'Blank separator pages are removed.'**
  String get splitBlankBody;

  /// a6-2: the mode when there are none.
  ///
  /// In en, this message translates to:
  /// **'No blank pages found.'**
  String get splitNoBlankPages;

  /// a6-2: the amount of Every few pages.
  ///
  /// In en, this message translates to:
  /// **'Pages per file'**
  String get splitPagesPerFile;

  /// a6-2: the amount of By file size.
  ///
  /// In en, this message translates to:
  /// **'Largest file'**
  String get splitLargest;

  /// a6-2: the template field.
  ///
  /// In en, this message translates to:
  /// **'File names'**
  String get splitFileNames;

  /// a6-2: the folder select.
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get splitSaveTo;

  /// a6-2: a choice.
  ///
  /// In en, this message translates to:
  /// **'Same folder as the original'**
  String get splitSameFolder;

  /// a6-2: a choice.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder…'**
  String get splitChooseFolder;

  /// a6-2: a file over the size asked for.
  ///
  /// In en, this message translates to:
  /// **'One page alone is larger than this size.'**
  String get splitOverLimit;

  /// a6-2: an encrypted document (M4 plan, question 6).
  ///
  /// In en, this message translates to:
  /// **'The new files won’t have this document’s password.'**
  String get splitNotProtected;

  /// a6-2: a signed document (M4 plan, question 6).
  ///
  /// In en, this message translates to:
  /// **'The new files won’t carry its signatures.'**
  String get splitNotSigned;

  /// a6-2: the primary button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Split into 1 file} other{Split into {formatted} files}}'**
  String splitAction(int count, String formatted);

  /// Create PDF (B019, no board): a source.
  ///
  /// In en, this message translates to:
  /// **'Blank page'**
  String get createBlank;

  /// Create PDF (B019, no board): a source.
  ///
  /// In en, this message translates to:
  /// **'From files…'**
  String get createFromFiles;

  /// Create PDF (B019, no board): a source, disabled (B176).
  ///
  /// In en, this message translates to:
  /// **'From the clipboard'**
  String get createFromClipboard;

  /// Create PDF: the new file's name to begin with.
  ///
  /// In en, this message translates to:
  /// **'Untitled.pdf'**
  String get createDefaultName;

  /// a11-6b: the title of a task that splits a document (G45).
  ///
  /// In en, this message translates to:
  /// **'Splitting {name}'**
  String jobSplittingTitle(String name);

  /// a11-6b: the title of the finished split.
  ///
  /// In en, this message translates to:
  /// **'Split {name}'**
  String jobSplitTitle(String name);

  /// a11-6b: the title of a failed split.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t split {name}'**
  String jobSplitFailedTitle(String name);

  /// a11-6b: the title of a task that combines files (G45).
  ///
  /// In en, this message translates to:
  /// **'Combining into {name}'**
  String jobCombiningTitle(String name);

  /// a11-6b: the title of the finished combine.
  ///
  /// In en, this message translates to:
  /// **'Combined into {name}'**
  String jobCombinedTitle(String name);

  /// a11-6b: the title of a failed combine.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t combine into {name}'**
  String jobCombineFailedTitle(String name);

  /// a11-6b: the title of a task that creates a PDF.
  ///
  /// In en, this message translates to:
  /// **'Creating {name}'**
  String jobCreatingTitle(String name);

  /// a11-6b: the title of the finished Create PDF.
  ///
  /// In en, this message translates to:
  /// **'Created {name}'**
  String jobCreatedTitle(String name);

  /// a11-6b: the title of a failed Create PDF; also a toast.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t create {name}'**
  String jobCreateFailedTitle(String name);

  /// FmComments's heading.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// FmComments: the filter button.
  ///
  /// In en, this message translates to:
  /// **'Filter and sort'**
  String get commentsFilter;

  /// FmComments: the More button.
  ///
  /// In en, this message translates to:
  /// **'More: export summary, flatten, hide all'**
  String get commentsMore;

  /// FmComments: the status control's name.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commentsStatus;

  /// FmComments: status.
  ///
  /// In en, this message translates to:
  /// **'Open {count}'**
  String commentsStatusOpen(String count);

  /// FmComments: status.
  ///
  /// In en, this message translates to:
  /// **'Resolved {count}'**
  String commentsStatusResolved(String count);

  /// FmComments: status.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String commentsStatusAll(String count);

  /// FmComments: filter's name.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get commentsFilterAuthor;

  /// FmComments: filter's name.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commentsFilterType;

  /// FmComments: filter's name.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get commentsFilterSort;

  /// FmComments: author filter.
  ///
  /// In en, this message translates to:
  /// **'All people'**
  String get commentsAllPeople;

  /// FmComments: type filter.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commentsTypeNotes;

  /// FmComments: type filter.
  ///
  /// In en, this message translates to:
  /// **'Text markup'**
  String get commentsTypeMarkup;

  /// FmComments: type filter.
  ///
  /// In en, this message translates to:
  /// **'Drawings'**
  String get commentsTypeDrawings;

  /// FmComments: type filter.
  ///
  /// In en, this message translates to:
  /// **'Stamps'**
  String get commentsTypeStamps;

  /// FmComments: type filter.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get commentsTypeOther;

  /// FmComments: sort.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get commentsSortNewest;

  /// FmComments: sort.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get commentsSortAuthor;

  /// FmComments: sort.
  ///
  /// In en, this message translates to:
  /// **'Page order'**
  String get commentsSortOther;

  /// FmComments: G35's notice.
  ///
  /// In en, this message translates to:
  /// **'This document is certified to allow comments: they keep its certification valid.'**
  String get commentsCertifiedNote;

  /// FmComments: a reader's limit cut the list.
  ///
  /// In en, this message translates to:
  /// **'This file has more comments than Ferman lists.'**
  String get commentsTruncated;

  /// FmComments: empty (G46).
  ///
  /// In en, this message translates to:
  /// **'No comments'**
  String get commentsEmptyTitle;

  /// FmComments: empty (G46).
  ///
  /// In en, this message translates to:
  /// **'Pick a tool above, then mark up the page.'**
  String get commentsEmptyBody;

  /// FmComments: no match (G46).
  ///
  /// In en, this message translates to:
  /// **'No comments match'**
  String get commentsNoMatchTitle;

  /// FmComments: no match (G46).
  ///
  /// In en, this message translates to:
  /// **'Change the status or filters to see others.'**
  String get commentsNoMatchBody;

  /// FmComments's footer.
  ///
  /// In en, this message translates to:
  /// **'Comments are saved in the PDF. Mentions travel with the file; Ferman doesn’t send notifications.'**
  String get commentsFootnote;

  /// FmComments: More.
  ///
  /// In en, this message translates to:
  /// **'Export summary…'**
  String get commentsExportSummary;

  /// FmComments: More.
  ///
  /// In en, this message translates to:
  /// **'Flatten…'**
  String get commentsFlatten;

  /// FmComments: More.
  ///
  /// In en, this message translates to:
  /// **'Hide all'**
  String get commentsHideAll;

  /// a4-5's notice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{shown} comment hidden} other{{shown} comments hidden}}'**
  String commentsHidden(int count, String shown);

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get commentKindHighlight;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get commentKindUnderline;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get commentKindStrikeOut;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Squiggly underline'**
  String get commentKindSquiggly;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get commentKindNote;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get commentKindFreeText;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get commentKindCallout;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get commentKindInk;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get commentKindSquare;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get commentKindCircle;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get commentKindLine;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get commentKindPolygon;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Stamp'**
  String get commentKindStamp;

  /// A kind of annotation.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentKindOther;

  /// a4-1's floating bar's name.
  ///
  /// In en, this message translates to:
  /// **'{kind} style'**
  String commentStyleBar(String kind);

  /// a4-1's style bar.
  ///
  /// In en, this message translates to:
  /// **'Stroke width'**
  String get commentStrokeWidth;

  /// a4-1's style bar.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get commentOpacity;

  /// a4-1's style bar.
  ///
  /// In en, this message translates to:
  /// **'Open comment'**
  String get commentOpen;

  /// a4-1's style bar.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentDelete;

  /// G46's context menu's name.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentMenu;

  /// G46's context menu.
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get commentEditText;

  /// a4-1d: the note's More.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commentMore;

  /// a4-1d: the note's Close.
  ///
  /// In en, this message translates to:
  /// **'Close note'**
  String get commentCloseNote;

  /// a4-1d: the note's name.
  ///
  /// In en, this message translates to:
  /// **'Note from {author}'**
  String commentNoteFrom(String author);

  /// a4-2's Reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentReply;

  /// a4-2's Resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get commentResolve;

  /// a4-2's Reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get commentReopen;

  /// a4-2's mention list.
  ///
  /// In en, this message translates to:
  /// **'People in this document'**
  String get commentPeople;

  /// The annotated text on a card.
  ///
  /// In en, this message translates to:
  /// **'“{text}”'**
  String commentQuote(String text);

  /// FmComments: collapsed replies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{shown} reply} other{{shown} replies}}'**
  String commentReplies(int count, String shown);

  /// FmComments: a resolved card.
  ///
  /// In en, this message translates to:
  /// **'Resolved by {name} · {time}'**
  String commentResolvedBy(String name, String time);

  /// FmComments: a comment's time.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commentYesterday;

  /// a4-2: how a card is announced.
  ///
  /// In en, this message translates to:
  /// **'{author}, {kind} on page {page}{resolved, plural, =0{} other{, resolved}}{count, plural, =0{} =1{, {shown} reply} other{, {shown} replies}}'**
  String commentCardLabel(
    String author,
    String kind,
    String page,
    int resolved,
    int count,
    String shown,
  );

  /// History step.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get commentStepAdd;

  /// History step.
  ///
  /// In en, this message translates to:
  /// **'Change comment'**
  String get commentStepChange;

  /// History step.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get commentStepDelete;

  /// History step.
  ///
  /// In en, this message translates to:
  /// **'Reply to comment'**
  String get commentStepReply;

  /// History step.
  ///
  /// In en, this message translates to:
  /// **'Resolve comment'**
  String get commentStepResolve;

  /// History step.
  ///
  /// In en, this message translates to:
  /// **'Reopen comment'**
  String get commentStepReopen;

  /// G46: the delete's toast.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get commentDeletedToast;

  /// G46: the delete's toast.
  ///
  /// In en, this message translates to:
  /// **'With its replies.'**
  String get commentDeletedNote;

  /// G46: the first comment asks.
  ///
  /// In en, this message translates to:
  /// **'Your name on comments'**
  String get commentNameTitle;

  /// G46: the first comment asks.
  ///
  /// In en, this message translates to:
  /// **'Others who open this PDF see it beside your comments. You can change it in Settings › General, or leave it empty.'**
  String get commentNameBody;

  /// G46: the first comment asks.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commentNameSave;

  /// Settings › General (G46).
  ///
  /// In en, this message translates to:
  /// **'Your name for comments'**
  String get settingsCommenterName;

  /// G46: the on-page editor's name.
  ///
  /// In en, this message translates to:
  /// **'Comment text'**
  String get commentTextField;

  /// The summary's suggested file name.
  ///
  /// In en, this message translates to:
  /// **'Comments.pdf'**
  String get commentSummaryFile;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get commentColumnPage;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commentColumnType;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get commentColumnAuthor;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commentColumnDate;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get commentColumnText;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get commentColumnReplies;

  /// Summary CSV column.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commentColumnStatus;

  /// Summary: an open comment.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commentStatusOpen;

  /// Summary: a resolved comment.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get commentStatusResolved;

  /// Task drawer: the summary.
  ///
  /// In en, this message translates to:
  /// **'Writing {name}'**
  String jobSummaryRunningTitle(String name);

  /// Task drawer: the summary.
  ///
  /// In en, this message translates to:
  /// **'Wrote {name}'**
  String jobSummaryDoneTitle(String name);

  /// Task drawer: the summary.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t write {name}'**
  String jobSummaryFailedTitle(String name);

  /// The summary’s suggested file name as a CSV (a4-4).
  ///
  /// In en, this message translates to:
  /// **'Comments.csv'**
  String get commentSummaryCsvFile;

  /// a4-4: the dialog’s title.
  ///
  /// In en, this message translates to:
  /// **'Export comment summary'**
  String get summaryTitle;

  /// a4-4: the format control’s label.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get summaryFormat;

  /// a4-4: a format.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get summaryCsv;

  /// a4-4: the layout cards’ group name, for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get summaryLayout;

  /// a4-4: a layout.
  ///
  /// In en, this message translates to:
  /// **'Page and comments'**
  String get summaryPageAndComments;

  /// a4-4: the layout’s line.
  ///
  /// In en, this message translates to:
  /// **'Numbered markers beside each page'**
  String get summaryPageAndCommentsHint;

  /// a4-4: a layout.
  ///
  /// In en, this message translates to:
  /// **'Comments only'**
  String get summaryCommentsOnly;

  /// a4-4: the layout’s line.
  ///
  /// In en, this message translates to:
  /// **'A list, grouped by page'**
  String get summaryCommentsOnlyHint;

  /// a4-4: a layout.
  ///
  /// In en, this message translates to:
  /// **'Page, then list'**
  String get summaryPageThenList;

  /// a4-4: the layout’s line.
  ///
  /// In en, this message translates to:
  /// **'Full page followed by its comments'**
  String get summaryPageThenListHint;

  /// a4-4: what the summary holds; {count} is formatted.
  ///
  /// In en, this message translates to:
  /// **'Open comments ({count})'**
  String summaryOpen(String count);

  /// a4-4: what the summary holds.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get summaryReplies;

  /// a4-4: what the summary holds; {count} is formatted.
  ///
  /// In en, this message translates to:
  /// **'Resolved comments ({count})'**
  String summaryResolved(String count);

  /// a4-4: what the summary holds.
  ///
  /// In en, this message translates to:
  /// **'Pages without comments'**
  String get summaryEmptyPages;

  /// a4-4: the order’s label.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get summarySortBy;

  /// a4-4: an order; the others are the Date and Author columns.
  ///
  /// In en, this message translates to:
  /// **'Page order'**
  String get summarySortPage;

  /// a4-4: the paper’s label.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get summaryPaper;

  /// a4-4: the preview’s label.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get summaryPreview;

  /// a4-4: the action; the save panel follows.
  ///
  /// In en, this message translates to:
  /// **'Export summary…'**
  String get summaryExport;

  /// Task drawer: a summary that failed on a page whose content Ferman cannot copy yet (B202).
  ///
  /// In en, this message translates to:
  /// **'A page is drawn in a way Ferman can’t picture in a summary yet. The Comments only layout or a CSV works.'**
  String get jobSummaryPageUnsupported;

  /// a4-5b: the title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Flatten 1 comment into the pages?} other{Flatten {formatted} comments into the pages?}}'**
  String flattenTitle(int count, String formatted);

  /// a4-5b: the consequence; the last sentence is about appearance, not a signature’s validity (G146).
  ///
  /// In en, this message translates to:
  /// **'They become part of the page. Nobody will be able to edit, reply to, hide or remove them, in Ferman or any other app. Form fields and signatures look as they did.'**
  String get flattenBody;

  /// a4-5b: a choice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{All {formatted} comments}}'**
  String flattenAll(int count, String formatted);

  /// a4-5b: a choice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No resolved comments} =1{Only the 1 resolved comment} other{Only the {formatted} resolved comments}}'**
  String flattenResolved(int count, String formatted);

  /// a4-5b: the copy written first (G146).
  ///
  /// In en, this message translates to:
  /// **'Keep a copy with comments'**
  String get flattenKeepCopy;

  /// a4-5b: the copy’s name.
  ///
  /// In en, this message translates to:
  /// **'Saved as “{name}” next to the original.'**
  String flattenKeepCopyHint(String name);

  /// a4-5b: the copy’s file name without its extension.
  ///
  /// In en, this message translates to:
  /// **'{stem} — with comments'**
  String flattenCopyName(String stem);

  /// a4-5b: the same, when that name is taken; {number} is 2 or more.
  ///
  /// In en, this message translates to:
  /// **'{stem} — with comments {number}'**
  String flattenCopyNameNumbered(String stem, int number);

  /// a4-5b: the action.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Flatten 1 comment} other{Flatten {formatted} comments}}'**
  String flattenAction(int count, String formatted);

  /// History: the flatten step (a4-5b).
  ///
  /// In en, this message translates to:
  /// **'Flatten comments'**
  String get commentStepFlatten;

  /// Task drawer: flatten.
  ///
  /// In en, this message translates to:
  /// **'Flattening comments in {name}'**
  String jobFlatteningTitle(String name);

  /// Task drawer: flatten.
  ///
  /// In en, this message translates to:
  /// **'Flattened comments in {name}'**
  String jobFlattenedTitle(String name);

  /// Task drawer: flatten; nothing in the document changed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t flatten comments in {name}'**
  String jobFlattenFailedTitle(String name);

  /// Task drawer: a flatten that failed on a page whose content Ferman cannot change yet (B202).
  ///
  /// In en, this message translates to:
  /// **'A page is drawn in a way Ferman can’t flatten into yet. Nothing changed.'**
  String get jobFlattenPageUnsupported;

  /// Search results: a match in a comment (B128).
  ///
  /// In en, this message translates to:
  /// **'Comment: {text}'**
  String sidebarSearchComment(String text);

  /// Name of the stamp library popover for screen readers (a4-3).
  ///
  /// In en, this message translates to:
  /// **'Stamps'**
  String get stampsTitle;

  /// Search field of the stamp library (a4-3).
  ///
  /// In en, this message translates to:
  /// **'Search stamps'**
  String get stampsSearch;

  /// Stamp library: a search with no result. No board draws it.
  ///
  /// In en, this message translates to:
  /// **'No stamps match your search'**
  String get stampsNoMatch;

  /// Stamp library: a group heading, shown in capitals (a4-3).
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get stampGroupStandard;

  /// Stamp library: a group heading, shown in capitals (a4-3).
  ///
  /// In en, this message translates to:
  /// **'With name and date'**
  String get stampGroupNamed;

  /// Stamp library: a group heading, shown in capitals (a4-3).
  ///
  /// In en, this message translates to:
  /// **'My stamps'**
  String get stampGroupMine;

  /// Stamp library: opens the Create stamp dialog (a4-3).
  ///
  /// In en, this message translates to:
  /// **'Create stamp…'**
  String get stampCreate;

  /// Stamp library: asks for a stamp file (a4-3).
  ///
  /// In en, this message translates to:
  /// **'Import…'**
  String get stampImport;

  /// Menu of a stamp in My stamps: writes it to a file (G153).
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get stampExport;

  /// Menu of a stamp in My stamps: removes it (G153).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get stampDelete;

  /// File type in the open panel for a stamp file.
  ///
  /// In en, this message translates to:
  /// **'Ferman stamps'**
  String get stampFileFilter;

  /// Toast title: the chosen file is no stamp.
  ///
  /// In en, this message translates to:
  /// **'This stamp can’t be imported'**
  String get stampImportFailed;

  /// Toast message: the chosen file is no stamp.
  ///
  /// In en, this message translates to:
  /// **'The file isn’t a Ferman stamp, or it is damaged.'**
  String get stampImportFailedBody;

  /// Toast title: the stamp's file could not be written.
  ///
  /// In en, this message translates to:
  /// **'The stamp couldn’t be exported'**
  String get stampExportFailed;

  /// Toast title: the limit of saved stamps is reached.
  ///
  /// In en, this message translates to:
  /// **'My stamps is full. Delete one first.'**
  String get stampsFull;

  /// Title of the Create stamp dialog (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Create stamp'**
  String get createStampTitle;

  /// Create stamp: the field for the stamp's text (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get createStampText;

  /// Create stamp: heading of the second line's choices (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Second line'**
  String get createStampSecondLine;

  /// Create stamp: the second line has the name (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'My name'**
  String get createStampMyName;

  /// Create stamp: the second line has the date (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get createStampDate;

  /// Create stamp: the second line has the time (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get createStampTime;

  /// Create stamp: accessible name of the name field (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Name on the stamp'**
  String get createStampName;

  /// Create stamp: heading of the ink choice (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get createStampColour;

  /// Create stamp: the seal-red ink (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Seal'**
  String get stampToneSeal;

  /// Create stamp: the blue ink (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get stampToneInk;

  /// Create stamp: the green ink (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get stampToneGreen;

  /// Create stamp: the grey ink (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get stampToneGrey;

  /// Create stamp: the language whose rules make the capitals (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Language for capitals'**
  String get createStampCaps;

  /// Create stamp: a language for capitals, with a sample (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Turkish (İNCELENDİ)'**
  String get createStampLanguageTurkish;

  /// Create stamp: a language for capitals (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get createStampLanguageEnglish;

  /// Create stamp: a language for capitals (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get createStampLanguageGerman;

  /// Create stamp: heading of the preview (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get createStampPreview;

  /// Create stamp: the note under the preview (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Saved to My stamps on this device.'**
  String get createStampSavedNote;

  /// Create stamp: the primary button (a4-3b).
  ///
  /// In en, this message translates to:
  /// **'Save stamp'**
  String get createStampSave;

  /// Shapes menu (a4-1).
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get shapeRectangle;

  /// Shapes menu (a4-1).
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get shapeEllipse;

  /// Shapes menu (a4-1).
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get shapeArrow;

  /// Shapes menu (a4-1).
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get shapeLine;

  /// Shapes menu (a4-1).
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get shapePolygon;

  /// Shapes menu: a placed shape leaves the tool on (a4-1).
  ///
  /// In en, this message translates to:
  /// **'Keep tool selected'**
  String get shapesKeepTool;

  /// Name of the history step that adds a shape.
  ///
  /// In en, this message translates to:
  /// **'Add shape'**
  String get stepAddShape;

  /// Name of the history step that adds a stamp.
  ///
  /// In en, this message translates to:
  /// **'Add stamp'**
  String get stepAddStamp;

  /// Screen readers: the page while a stamp is being placed.
  ///
  /// In en, this message translates to:
  /// **'Click the page to place the stamp, or press Enter to place it mid-page.'**
  String get placeStampHint;

  /// Screen readers: the page while a shape is being drawn.
  ///
  /// In en, this message translates to:
  /// **'Drag on the page to draw the shape, or press Enter to place it mid-page.'**
  String get placeShapeHint;

  /// Screen readers: the page while a polygon is being drawn.
  ///
  /// In en, this message translates to:
  /// **'Click each corner of the polygon, then press Enter or click the first corner.'**
  String get placePolygonHint;

  /// a3-6: the Links panel's title.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get linksTitle;

  /// a3-6: the panel's note. The board also says 'or a file'; file links are refused (G145).
  ///
  /// In en, this message translates to:
  /// **'Ferman asks before opening a web link from a PDF.'**
  String get linksNote;

  /// a3-6: the panel with no links; not drawn.
  ///
  /// In en, this message translates to:
  /// **'No links in this document.'**
  String get linksEmpty;

  /// a3-6: a limit cut the list short.
  ///
  /// In en, this message translates to:
  /// **'This document has too many links to list them all.'**
  String get linksTruncated;

  /// a3-6: why Add link is disabled with nothing selected.
  ///
  /// In en, this message translates to:
  /// **'Select the text to link first'**
  String get linksSelectTextFirst;

  /// a3-6: a kind of link, and a segment of Edit link.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get linksKindWeb;

  /// a3-6: a kind of link, and a segment of Edit link.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get linksKindMail;

  /// a3-6: a kind of link, and a segment of Edit link.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get linksKindPage;

  /// a3-6: a link that would run a script (G145).
  ///
  /// In en, this message translates to:
  /// **'Script, not run'**
  String get linksKindScript;

  /// a3-6: a link that would start a program (G145).
  ///
  /// In en, this message translates to:
  /// **'Program, not started'**
  String get linksKindLaunch;

  /// a3-6: a link to another file (G145).
  ///
  /// In en, this message translates to:
  /// **'File, not opened'**
  String get linksKindFile;

  /// a3-6: an address of a scheme Ferman does not open (G145).
  ///
  /// In en, this message translates to:
  /// **'Address, not opened'**
  String get linksKindAddress;

  /// a3-6: an action Ferman does not know; it stays in the file.
  ///
  /// In en, this message translates to:
  /// **'Unknown action, kept'**
  String get linksKindAction;

  /// a3-6: a link with no action.
  ///
  /// In en, this message translates to:
  /// **'Does nothing'**
  String get linksKindNothing;

  /// a3-6: where a link to a page goes.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String linksPage(String page);

  /// a3-6: a broken link that names no page.
  ///
  /// In en, this message translates to:
  /// **'Missing page'**
  String get linksPageMissing;

  /// a3-6: a row's second line.
  ///
  /// In en, this message translates to:
  /// **'{kind} · page {page}'**
  String linksMeta(String kind, String page);

  /// a3-6: the second line of the row being edited.
  ///
  /// In en, this message translates to:
  /// **'{kind} · page {page} · editing'**
  String linksMetaEditing(String kind, String page);

  /// a3-6: the popover's title for a new link.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get linkAddTitle;

  /// a3-6: the popover's title.
  ///
  /// In en, this message translates to:
  /// **'Edit link'**
  String get linkEditTitle;

  /// a3-6: the name of the type control.
  ///
  /// In en, this message translates to:
  /// **'Link to'**
  String get linkTo;

  /// a3-6: a segment of Edit link, disabled (B200).
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get linkTypeFile;

  /// a3-6: the field's label.
  ///
  /// In en, this message translates to:
  /// **'Web address'**
  String get linkFieldWeb;

  /// a3-6: the field's label.
  ///
  /// In en, this message translates to:
  /// **'E-mail address'**
  String get linkFieldMail;

  /// a3-6: the field's label.
  ///
  /// In en, this message translates to:
  /// **'Page number'**
  String get linkFieldPage;

  /// a3-6: the field's label.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get linkAppearance;

  /// a3-6: an appearance.
  ///
  /// In en, this message translates to:
  /// **'Invisible (text keeps its look)'**
  String get linkLookNone;

  /// a3-6: an appearance.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get linkLookUnderline;

  /// a3-6: an appearance.
  ///
  /// In en, this message translates to:
  /// **'Thin box'**
  String get linkLookBox;

  /// a3-6: button.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get linkRemove;

  /// a3-6: button.
  ///
  /// In en, this message translates to:
  /// **'Save link'**
  String get linkSave;

  /// The history step's name.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get linkStepAdd;

  /// The history step's name.
  ///
  /// In en, this message translates to:
  /// **'Edit link'**
  String get linkStepEdit;

  /// The history step's name.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get linkStepRemove;

  /// a3-6: the Web field's error.
  ///
  /// In en, this message translates to:
  /// **'Type a web address that starts with http:// or https://.'**
  String get linkErrorWeb;

  /// a3-6: the E-mail field's error.
  ///
  /// In en, this message translates to:
  /// **'Type an e-mail address, like name@example.com.'**
  String get linkErrorMail;

  /// A toast's title when the engine refuses a link change.
  ///
  /// In en, this message translates to:
  /// **'The link wasn\'t changed'**
  String get linkFailedTitle;

  /// G145: the prompt before a web link.
  ///
  /// In en, this message translates to:
  /// **'Open this web address?'**
  String get linkOpenWebTitle;

  /// G145: the prompt before an e-mail link.
  ///
  /// In en, this message translates to:
  /// **'Write to this address?'**
  String get linkOpenMailTitle;

  /// G145: the prompt's description.
  ///
  /// In en, this message translates to:
  /// **'This link comes from the document. It opens in your own apps, so check that you trust where it goes.'**
  String get linkOpenDescription;

  /// G145: the prompt's button.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get linkOpenAction;

  /// A toast when the system opens nothing.
  ///
  /// In en, this message translates to:
  /// **'The link couldn\'t be opened'**
  String get linkOpenFailed;

  /// A toast when a broken link is clicked.
  ///
  /// In en, this message translates to:
  /// **'This link leads nowhere'**
  String get linkBrokenTitle;

  /// A toast when a link is not offered (G145).
  ///
  /// In en, this message translates to:
  /// **'Ferman didn\'t follow this link'**
  String get linkRefusedTitle;

  /// G145.
  ///
  /// In en, this message translates to:
  /// **'It would run a script, and Ferman doesn\'t run a document\'s scripts.'**
  String get linkRefusedScript;

  /// G145.
  ///
  /// In en, this message translates to:
  /// **'It would start {target}, and Ferman never starts programs for a document.'**
  String linkRefusedLaunch(String target);

  /// G145.
  ///
  /// In en, this message translates to:
  /// **'It points to another file, {target}, and Ferman doesn\'t open files from links.'**
  String linkRefusedFile(String target);

  /// G145.
  ///
  /// In en, this message translates to:
  /// **'Ferman doesn\'t open this kind of address: {target}'**
  String linkRefusedAddress(String target);

  /// G145.
  ///
  /// In en, this message translates to:
  /// **'It does something Ferman doesn\'t know, so it stays in the file and doesn\'t run.'**
  String get linkRefusedAction;

  /// a3-6: a link to a page the document does not have.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Broken: this document has {pages} page} other{Broken: this document has {pages} pages}}'**
  String linksBrokenMeta(int count, String pages);

  /// a3-6: the Page field's error.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This document has {pages} page.} other{Type a page from 1 to {pages}.}}'**
  String linkErrorPage(int count, String pages);

  /// a5-3: screen-reader name of the Draw, Type and Image choice in the signature pad.
  ///
  /// In en, this message translates to:
  /// **'Signature method'**
  String get signPadMethod;

  /// a5-3b: signature pad mode, drawing with a mouse, trackpad, pen or finger. A verb.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get signPadDraw;

  /// a5-3: signature pad mode, the name typed in a handwriting style. A verb.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get signPadType;

  /// a5-3c: signature pad mode, a photo or scan of a signature on paper; also the caption of such a saved signature in the Sign menu.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get signPadImage;

  /// a5-3b: screen-reader name of the drawing area.
  ///
  /// In en, this message translates to:
  /// **'Signature drawing area. Draw with a mouse, trackpad, pen or finger.'**
  String get signPadArea;

  /// a5-3: screen-reader name of the name field in the signature pad.
  ///
  /// In en, this message translates to:
  /// **'Type your name'**
  String get signPadTypeName;

  /// a5-3: placeholder of the name field in the signature pad.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get signPadNamePlaceholder;

  /// a5-3b: hint in the empty drawing area.
  ///
  /// In en, this message translates to:
  /// **'Sign above the line'**
  String get signPadDrawHint;

  /// a5-3: hint under the empty name field.
  ///
  /// In en, this message translates to:
  /// **'Type your name above the line'**
  String get signPadTypeHint;

  /// a5-3c: text in the empty image box. Ferman is the product name.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo or scan of your signature. Ferman removes the background.'**
  String get signPadImageHint;

  /// a5-3c: button that opens the system panel to choose an image.
  ///
  /// In en, this message translates to:
  /// **'Choose image…'**
  String get signPadChooseImage;

  /// a5-3: screen-reader name of the ink colour choice.
  ///
  /// In en, this message translates to:
  /// **'Ink color'**
  String get signPadInk;

  /// a5-3: ink colour name, read by screen readers.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get signPadBlack;

  /// a5-3: ink colour name, read by screen readers.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get signPadBlue;

  /// a5-3b: button that removes every stroke or the typed name. A verb.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signPadClear;

  /// a5-3: checkbox; a saved signature appears in the Sign menu next time.
  ///
  /// In en, this message translates to:
  /// **'Save on this device'**
  String get signPadSave;

  /// a5-3: title and main button of the dialog that creates a signature.
  ///
  /// In en, this message translates to:
  /// **'Add signature'**
  String get signDialogTitle;

  /// a5-3: title and main button of the same dialog while it creates initials.
  ///
  /// In en, this message translates to:
  /// **'Add initials'**
  String get signDialogTitleInitials;

  /// a5-3: screen-reader name of the Signature or Initials choice at the top of the dialog.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get signCreate;

  /// a5-3: choice at the top of the dialog.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signKindSignature;

  /// a5-3: choice at the top of the dialog; also the heading of the initials in the Sign menu, shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Initials'**
  String get signKindInitials;

  /// a5-3: screen-reader name of the three handwriting style tiles.
  ///
  /// In en, this message translates to:
  /// **'Handwriting style'**
  String get signHandwriting;

  /// a5-3: line shown instead of the style tiles when none of the three fonts has every letter of the typed name, as for an Arabic or Chinese name (design gap G149).
  ///
  /// In en, this message translates to:
  /// **'No handwriting style can write every letter of this name. Draw it or use an image instead.'**
  String get signNoStyle;

  /// a5-3: note at the start of the dialog's footer.
  ///
  /// In en, this message translates to:
  /// **'Saved only on this device.'**
  String get signSavedNote;

  /// a5-3d: screen-reader name of the Sign menu.
  ///
  /// In en, this message translates to:
  /// **'Saved signatures'**
  String get signMenuLabel;

  /// a5-3d: heading of the saved signatures in the Sign menu, shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Signatures'**
  String get signMenuSignatures;

  /// a5-3d: Sign menu item that opens the dialog.
  ///
  /// In en, this message translates to:
  /// **'Add signature…'**
  String get signMenuAdd;

  /// Sign menu item that opens the dialog while nothing is saved yet (design gap G47).
  ///
  /// In en, this message translates to:
  /// **'Create signature…'**
  String get signMenuCreate;

  /// a5-3d: Sign menu item that opens Settings › Signatures.
  ///
  /// In en, this message translates to:
  /// **'Manage saved signatures…'**
  String get signMenuManage;

  /// a5-3d: caption of a drawn signature in the Sign menu.
  ///
  /// In en, this message translates to:
  /// **'Drawn'**
  String get signDrawn;

  /// Menu item of a saved signature in the Sign menu: deletes it from this device.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get signDelete;

  /// Toast when a new signature cannot be written to the app's data folder.
  ///
  /// In en, this message translates to:
  /// **'The signature couldn’t be saved on this device. It’s still ready to place.'**
  String get signSaveFailed;

  /// Toast when the chosen signature image is too large.
  ///
  /// In en, this message translates to:
  /// **'This image is too large. Choose one under 6 MB.'**
  String get signImageTooLarge;

  /// Filter name in the system open panel for a signature image.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get signImageFilter;

  /// Name of the history step that places a signature.
  ///
  /// In en, this message translates to:
  /// **'Add signature'**
  String get stepAddSignature;

  /// Name of the history step that places initials.
  ///
  /// In en, this message translates to:
  /// **'Add initials'**
  String get stepAddInitials;

  /// Screen-reader hint of the page while a signature is being placed (a5-3d).
  ///
  /// In en, this message translates to:
  /// **'Click the page or a signature field to place it, or press Enter to place it mid-page. Drag its corners to resize it and its round handle to turn it, then press Enter.'**
  String get placeSignatureHint;

  /// FmFormPanel's heading (a5-1).
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get formPanelTitle;

  /// FmFormPanel: the More button.
  ///
  /// In en, this message translates to:
  /// **'More: clear form, export data'**
  String get formMore;

  /// FmFormPanel: the required count over its bar (a5-1).
  ///
  /// In en, this message translates to:
  /// **'{filled} of {total} required fields'**
  String formRequiredProgress(String filled, String total);

  /// FmFormPanel's summary: how many fields.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field} other{{formatted} fields}}'**
  String formSummaryFields(int count, String formatted);

  /// FmFormPanel and the field navigation: required fields still empty.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 required left} other{{formatted} required left}}'**
  String formRequiredLeft(int count, String formatted);

  /// FmFormPanel's summary once every required field is filled.
  ///
  /// In en, this message translates to:
  /// **'All required fields are filled'**
  String get formAllRequiredFilled;

  /// FmFormPanel's summary: the field the person is in.
  ///
  /// In en, this message translates to:
  /// **'field {current} of {total}'**
  String formFieldOf(String current, String total);

  /// FmFormPanel: the switch that tints the fields.
  ///
  /// In en, this message translates to:
  /// **'Highlight fields'**
  String get formHighlight;

  /// FmFormPanel and the form bar: shows the fields' order numbers.
  ///
  /// In en, this message translates to:
  /// **'Show tab order'**
  String get formShowOrder;

  /// The form bar's button while the order shows.
  ///
  /// In en, this message translates to:
  /// **'Hide tab order'**
  String get formHideOrder;

  /// FmFormPanel: the signed-form notice's title (G47).
  ///
  /// In en, this message translates to:
  /// **'Signed form'**
  String get formSignedTitle;

  /// FmFormPanel: the signed-form notice when filling keeps the certification (G35).
  ///
  /// In en, this message translates to:
  /// **'Its certification allows filling in, so it stays valid.'**
  String get formSignedKeeps;

  /// FmFormPanel: the signed-form notice when filling breaks a signature (G35).
  ///
  /// In en, this message translates to:
  /// **'Filling it in will invalidate its signature.'**
  String get formSignedBreaks;

  /// FmFormPanel: said once when a value takes bundled Plex (M4 decision 18).
  ///
  /// In en, this message translates to:
  /// **'Characters added in IBM Plex'**
  String get formFontNoticeTitle;

  /// FmFormPanel: the font notice's text.
  ///
  /// In en, this message translates to:
  /// **'This form’s font has no glyphs for some characters you typed, so Ferman added {fonts} to the document for them.'**
  String formFontNoticeBody(String fonts);

  /// FmFormPanel: closes the font notice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get formDismiss;

  /// FmFormPanel: a required field not filled yet.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get formRequired;

  /// FmFormPanel: a field whose missing characters were kept out (Keep).
  ///
  /// In en, this message translates to:
  /// **'Some characters can’t be shown in this field’s font'**
  String get formMarkedField;

  /// FmFormPanel's footer and More menu.
  ///
  /// In en, this message translates to:
  /// **'Clear form…'**
  String get formClear;

  /// FmFormPanel's primary button.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get formFinish;

  /// FmFormPanel's More menu: not built yet.
  ///
  /// In en, this message translates to:
  /// **'Export data…'**
  String get formExportData;

  /// The bar over a form in Fill & Sign (a5-1).
  ///
  /// In en, this message translates to:
  /// **'This PDF is a fillable form.'**
  String get formBannerTitle;

  /// The form bar's text.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field, {required} required. Tab moves to the next field.} other{{formatted} fields, {required} required. Tab moves to the next field.}}'**
  String formBannerBody(int count, String formatted, String required);

  /// The form bar: hides it.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get formBannerHide;

  /// The bar over a page without fields (a5-4).
  ///
  /// In en, this message translates to:
  /// **'This PDF has no form fields.'**
  String get fillBannerTitle;

  /// The no-fields bar's text.
  ///
  /// In en, this message translates to:
  /// **'Click a line or box to type, or let Ferman find the fields.'**
  String get fillBannerBody;

  /// The no-fields bar's button (Prepare form, P4).
  ///
  /// In en, this message translates to:
  /// **'Find fields'**
  String get fillFindFields;

  /// The field navigation's button.
  ///
  /// In en, this message translates to:
  /// **'Previous field'**
  String get formPreviousField;

  /// The field navigation's button.
  ///
  /// In en, this message translates to:
  /// **'Next field'**
  String get formNextField;

  /// The field navigation: the field the person is in.
  ///
  /// In en, this message translates to:
  /// **'Field {current} of {total}'**
  String formNavField(String current, String total);

  /// The field navigation before any field is chosen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field} other{{formatted} fields}}'**
  String formNavFields(int count, String formatted);

  /// The field navigation's badge once every required field is filled (a5-3d).
  ///
  /// In en, this message translates to:
  /// **'All required filled'**
  String get formNavAllFilled;

  /// An empty signature field on the page (a5-2b).
  ///
  /// In en, this message translates to:
  /// **'Sign here'**
  String get formSignHere;

  /// A field's error: too long.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use at most 1 character.} other{Use at most {formatted} characters.}}'**
  String formErrorTooLong(int count, String formatted);

  /// A field's error: not a date in its format.
  ///
  /// In en, this message translates to:
  /// **'Enter a date as {pattern}.'**
  String formErrorDate(String pattern);

  /// A field's error: not a number.
  ///
  /// In en, this message translates to:
  /// **'Enter a number.'**
  String get formErrorNumber;

  /// A field's error: out of its range (a5-2).
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}.'**
  String formErrorRange(String min, String max);

  /// A field's error: under its least value.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of at least {min}.'**
  String formErrorMin(String min);

  /// A field's error: over its greatest value.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of at most {max}.'**
  String formErrorMax(String max);

  /// A required field left empty, after Finish (a5-2b).
  ///
  /// In en, this message translates to:
  /// **'Required to submit.'**
  String get formErrorRequired;

  /// A required signature field left empty, after Finish (a5-2b).
  ///
  /// In en, this message translates to:
  /// **'Sign before finishing.'**
  String get formErrorSign;

  /// A required choice left empty, after Finish (a5-2b).
  ///
  /// In en, this message translates to:
  /// **'Choose an option.'**
  String get formErrorChoose;

  /// The date picker's name (a5-2).
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get formChooseDate;

  /// The date picker's note (a5-2).
  ///
  /// In en, this message translates to:
  /// **'Format {pattern} · from the form'**
  String formDateFormat(String pattern);

  /// The date picker's button.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get formPreviousMonth;

  /// The date picker's button.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get formNextMonth;

  /// The date picker's button.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get formToday;

  /// The history step of a field's value.
  ///
  /// In en, this message translates to:
  /// **'Fill “{name}”'**
  String formStepFill(String name);

  /// The history step of Clear form.
  ///
  /// In en, this message translates to:
  /// **'Clear form'**
  String get formStepClear;

  /// The history step of Finish's flatten.
  ///
  /// In en, this message translates to:
  /// **'Finish form'**
  String get formStepFinish;

  /// The history step of Fill anything's text.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get fillStepText;

  /// The history step of Fill anything's check, cross or dot.
  ///
  /// In en, this message translates to:
  /// **'Add mark'**
  String get fillStepMark;

  /// Toast: a value removed the form's XFA (M4 question 12).
  ///
  /// In en, this message translates to:
  /// **'The form’s XFA data was removed'**
  String get formXfaRemovedTitle;

  /// Toast: the XFA notice's text.
  ///
  /// In en, this message translates to:
  /// **'Readers that use XFA would have shown the old values. The original stays in the file’s earlier version.'**
  String get formXfaRemovedBody;

  /// G47's Finish dialog.
  ///
  /// In en, this message translates to:
  /// **'Finish the form'**
  String get formFinishTitle;

  /// G47's Finish dialog: its text.
  ///
  /// In en, this message translates to:
  /// **'All required fields are filled. Choose how to keep the form, then save it.'**
  String get formFinishBody;

  /// G47's Finish dialog: the first choice.
  ///
  /// In en, this message translates to:
  /// **'Flatten the fields'**
  String get formFinishFlatten;

  /// G47's Finish dialog: what flattening does.
  ///
  /// In en, this message translates to:
  /// **'They become part of the page and can no longer be changed.'**
  String get formFinishFlattenBody;

  /// G47's Finish dialog: the second choice.
  ///
  /// In en, this message translates to:
  /// **'Keep the fields editable'**
  String get formFinishKeep;

  /// G47's Finish dialog: what keeping does.
  ///
  /// In en, this message translates to:
  /// **'Anyone who opens the file can still change the values.'**
  String get formFinishKeepBody;

  /// G47's Finish dialog: the default button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get formFinishSave;

  /// G47's Finish dialog: saves to another file.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get formFinishSaveAs;

  /// G47's Clear form confirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear the form?'**
  String get formClearTitle;

  /// G47's Clear form confirmation: its text.
  ///
  /// In en, this message translates to:
  /// **'Every value in this form is removed. Signatures stay. You can undo this.'**
  String get formClearBody;

  /// G47's Clear form confirmation: the button.
  ///
  /// In en, this message translates to:
  /// **'Clear form'**
  String get formClearConfirm;

  /// Ask each time (a11-1c, M4 decision 18).
  ///
  /// In en, this message translates to:
  /// **'Characters missing from this field’s font'**
  String get formFontAskTitle;

  /// Ask each time: its text.
  ///
  /// In en, this message translates to:
  /// **'Ferman can draw them in IBM Plex, added to the document, or keep the field’s font and leave them out.'**
  String get formFontAskBody;

  /// Ask each time: the default button.
  ///
  /// In en, this message translates to:
  /// **'Use IBM Plex'**
  String get formFontAskPlex;

  /// Ask each time: keeps the font, marks the field.
  ///
  /// In en, this message translates to:
  /// **'Keep the field’s font'**
  String get formFontAskKeep;

  /// Fill anything's panel (a5-4).
  ///
  /// In en, this message translates to:
  /// **'Fill anything'**
  String get fillPanelTitle;

  /// Fill anything: Text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get fillToolText;

  /// Fill anything: Check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get fillToolCheck;

  /// Fill anything: Cross.
  ///
  /// In en, this message translates to:
  /// **'Cross'**
  String get fillToolCross;

  /// Fill anything: Dot.
  ///
  /// In en, this message translates to:
  /// **'Dot'**
  String get fillToolDot;

  /// Fill anything: Today's date.
  ///
  /// In en, this message translates to:
  /// **'Today’s date'**
  String get fillToolToday;

  /// Fill anything: Signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get fillToolSignature;

  /// Fill anything: the options' section.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get fillOptions;

  /// Fill anything's option.
  ///
  /// In en, this message translates to:
  /// **'Snap to lines and boxes'**
  String get fillSnap;

  /// Fill anything's option.
  ///
  /// In en, this message translates to:
  /// **'One character per comb box'**
  String get fillComb;

  /// Fill anything's ink.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get fillInk;

  /// Fill anything's ink: black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get fillInkBlack;

  /// Fill anything's ink: blue.
  ///
  /// In en, this message translates to:
  /// **'Blue (#1A3170)'**
  String get fillInkBlue;

  /// a2-4d: after findNoneBody, with Form fields ticked and Comments not.
  ///
  /// In en, this message translates to:
  /// **'Comments weren’t searched.'**
  String get findNotSearchedComments;

  /// Search results: a match in a form field's value (B128).
  ///
  /// In en, this message translates to:
  /// **'Form field: {text}'**
  String sidebarSearchFormField(String text);

  /// Task drawer: Compress (a9-1) while it runs.
  ///
  /// In en, this message translates to:
  /// **'Compressing {name}'**
  String jobCompressingTitle(String name);

  /// Task drawer: Compress, done.
  ///
  /// In en, this message translates to:
  /// **'Compressed {name}'**
  String jobCompressedTitle(String name);

  /// Task drawer: Compress failed; nothing was written.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t compress {name}'**
  String jobCompressFailedTitle(String name);

  /// Task drawer: Compress done, but the result was not smaller (decision 25).
  ///
  /// In en, this message translates to:
  /// **'It can’t get smaller, so nothing was written. The original stays as it is.'**
  String get jobCompressNotSmaller;

  /// Task drawer: Compress done; the sizes before and after, such as 24,6 MB → 6,8 MB.
  ///
  /// In en, this message translates to:
  /// **'{before} → {after}'**
  String jobCompressedSizes(String before, String after);

  /// Tooltip of Print (B121) when the document's permissions forbid printing.
  ///
  /// In en, this message translates to:
  /// **'The author doesn’t allow printing'**
  String get printForbidden;

  /// Toast after a print was handed to the system.
  ///
  /// In en, this message translates to:
  /// **'Sent {name} to the printer'**
  String printSent(String name);

  /// Toast when a print failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t print {name}'**
  String printFailed(String name);

  /// Print dialog (a9-6): the title; {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'Print “{name}”'**
  String printTitle(String name);

  /// Print dialog: opens the system print dialog for the whole document.
  ///
  /// In en, this message translates to:
  /// **'Use system dialog…'**
  String get printSystemDialog;

  /// Print dialog: the primary button, which opens the system print dialog.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printAction;

  /// Print dialog: the printer menu, set in the system dialog.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printPrinter;

  /// Print dialog: the printer menu's only entry.
  ///
  /// In en, this message translates to:
  /// **'Chosen in the system dialog'**
  String get printPrinterSystem;

  /// Print dialog: the number of copies, set in the system dialog.
  ///
  /// In en, this message translates to:
  /// **'Copies'**
  String get printCopies;

  /// Print dialog: the pages field.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get printPages;

  /// Print dialog: the pages field's placeholder; empty prints every page.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get printPagesAll;

  /// Print dialog: the layout choice.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get printLayout;

  /// Print dialog: one page per sheet.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get printLayoutPages;

  /// Print dialog: booklet layout (P5).
  ///
  /// In en, this message translates to:
  /// **'Booklet'**
  String get printLayoutBooklet;

  /// Print dialog: poster tiling (P5).
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get printLayoutPoster;

  /// Print dialog: duplex, set in the system dialog.
  ///
  /// In en, this message translates to:
  /// **'Both sides'**
  String get printBothSides;

  /// Print dialog: duplex along the long edge.
  ///
  /// In en, this message translates to:
  /// **'Long edge'**
  String get printLongEdge;

  /// Print dialog: duplex along the short edge.
  ///
  /// In en, this message translates to:
  /// **'Short edge'**
  String get printShortEdge;

  /// Print dialog: no duplex.
  ///
  /// In en, this message translates to:
  /// **'One side'**
  String get printOneSide;

  /// Print dialog: the scale menu.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get printScale;

  /// Print dialog: scale to the printable area.
  ///
  /// In en, this message translates to:
  /// **'Fit to printable area'**
  String get printScaleFit;

  /// Print dialog: print at the page's own size.
  ///
  /// In en, this message translates to:
  /// **'Actual size (100%)'**
  String get printScaleActual;

  /// Print dialog: a custom scale (later).
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get printScaleCustom;

  /// Print dialog: the heading of what prints.
  ///
  /// In en, this message translates to:
  /// **'Include'**
  String get printInclude;

  /// Print dialog: whether comments and stamps print; {n} is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Comments and stamps ({n})} other{Comments and stamps ({n})}}'**
  String printComments(int count, String n);

  /// Print dialog: form fields, which always print.
  ///
  /// In en, this message translates to:
  /// **'Form field contents'**
  String get printFormFields;

  /// Print dialog: hidden layers (later).
  ///
  /// In en, this message translates to:
  /// **'Hidden layers'**
  String get printHiddenLayers;

  /// Print dialog: the preview's previous sheet.
  ///
  /// In en, this message translates to:
  /// **'Previous sheet'**
  String get printPreviousSheet;

  /// Print dialog: the preview's next sheet.
  ///
  /// In en, this message translates to:
  /// **'Next sheet'**
  String get printNextSheet;

  /// Print dialog: under the preview; {paper} is the region's paper, A4 or Letter.
  ///
  /// In en, this message translates to:
  /// **'Sheet {sheet} of {sheets} · {paper}'**
  String printSheetOf(String sheet, String sheets, String paper);

  /// Compress: the suggested file name, without .pdf; {name} is the document's.
  ///
  /// In en, this message translates to:
  /// **'{name}, compressed'**
  String compressFileName(String name);

  /// Compress panel (a9-1): the title.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get compressTitle;

  /// Compress panel: the presets' group name for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get compressPreset;

  /// Compress preset.
  ///
  /// In en, this message translates to:
  /// **'High quality'**
  String get compressHighQuality;

  /// Compress preset.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get compressBalanced;

  /// Compress preset.
  ///
  /// In en, this message translates to:
  /// **'Smallest'**
  String get compressSmallest;

  /// Compress preset's line.
  ///
  /// In en, this message translates to:
  /// **'Images at 300 ppi, for printing.'**
  String get compressHighQualityDescription;

  /// Compress preset's line.
  ///
  /// In en, this message translates to:
  /// **'Images at 150 ppi, for sharing and reading on screen.'**
  String get compressBalancedDescription;

  /// Compress preset's line.
  ///
  /// In en, this message translates to:
  /// **'Images at 96 ppi, for e-mail. Text stays sharp.'**
  String get compressSmallestDescription;

  /// Compress: the custom preset (later, B182).
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get compressCustom;

  /// Compress: the custom preset's line.
  ///
  /// In en, this message translates to:
  /// **'Set image resolution, quality and what to remove.'**
  String get compressCustomDescription;

  /// Compress: an estimated size, such as ≈ 6,8 MB.
  ///
  /// In en, this message translates to:
  /// **'≈ {size}'**
  String compressAbout(String size);

  /// Compress: the size now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get compressNow;

  /// Compress: the estimated size after.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get compressAfter;

  /// Compress: under the sizes; the estimate samples images by their bytes (decision 26).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Estimated from {n} sample image. The exact size is shown after saving.} other{Estimated from {n} sample images. The exact size is shown after saving.}}'**
  String compressEstimateSampled(int count, String n);

  /// Compress: under the sizes when every image was measured.
  ///
  /// In en, this message translates to:
  /// **'Measured on every image. The exact size is shown after saving.'**
  String get compressEstimateExact;

  /// Compress: the section's title; {preset} is the preset's name.
  ///
  /// In en, this message translates to:
  /// **'What {preset} does'**
  String compressDoes(String preset);

  /// Compress: what the preset does.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recompresses {n} image to {ppi} ppi} other{Recompresses {n} images to {ppi} ppi}}'**
  String compressDoesImages(int count, String n, String ppi);

  /// Compress: what the preset does.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Merges {n} duplicate font copy} other{Merges {n} duplicate font copies}}'**
  String compressDoesFonts(int count, String n);

  /// Compress: what the preset does.
  ///
  /// In en, this message translates to:
  /// **'Removes unused objects and thumbnails'**
  String get compressDoesUnused;

  /// Compress: images in formats, masks or patterns it does not recompress (decision 26).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Leaves {n} image as it is: Ferman can’t recompress it} other{Leaves {n} images as they are: Ferman can’t recompress them}}'**
  String compressDoesLeft(int count, String n);

  /// Compress: what the preset never changes.
  ///
  /// In en, this message translates to:
  /// **'Keeps text, links, bookmarks and forms'**
  String get compressDoesKeeps;

  /// Compress: the warning on a signed document (decision 25).
  ///
  /// In en, this message translates to:
  /// **'This document is signed'**
  String get compressSignedTitle;

  /// Compress: the warning's text.
  ///
  /// In en, this message translates to:
  /// **'The compressed copy has no signatures. The signed original stays as it is.'**
  String get compressSignedBody;

  /// Compress: the primary button; the system save panel asks where.
  ///
  /// In en, this message translates to:
  /// **'Compress and save as…'**
  String get compressAction;

  /// Save as sheet: under Include comments when it is unchecked; {name} is the file name.
  ///
  /// In en, this message translates to:
  /// **'The file is saved as a copy without them; {name} stays open with its comments.'**
  String saveAsCommentsOff(String name);

  /// Save as sheet: under Remove edit history when it is checked (B138).
  ///
  /// In en, this message translates to:
  /// **'The file is written anew, without earlier revisions or deleted pages. Signatures stop being valid.'**
  String get saveAsHistoryOn;

  /// Save as sheet: under Remove edit history when it is unchecked (M4 plan question 5).
  ///
  /// In en, this message translates to:
  /// **'Deleted pages and earlier text stay in the file and can be recovered from it.'**
  String get saveAsHistoryOff;

  /// Version history (a9-8): the panel's title.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get versionTitle;

  /// Version history: how many versions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} version} other{{n} versions}}'**
  String versionCount(int count, String n);

  /// Version history: the list's name for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get versionList;

  /// Version history: the empty list.
  ///
  /// In en, this message translates to:
  /// **'No versions yet. Each save keeps one.'**
  String get versionNone;

  /// Version history: the foot (ADR 0022: versions live in the app data directory).
  ///
  /// In en, this message translates to:
  /// **'Kept for 30 days on this device. Change in Settings › Editing.'**
  String get versionKept;

  /// Version history: the current, unsaved state.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get versionNow;

  /// Version history: Now's time.
  ///
  /// In en, this message translates to:
  /// **'unsaved'**
  String get versionUnsaved;

  /// Version history: Now's line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Changes since the last save} =1{{n} edit since the last save} other{{n} edits since the last save}}'**
  String versionNowDetail(int count, String n);

  /// Version history: the file as it was opened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get versionOpened;

  /// Version history: the opened version's line.
  ///
  /// In en, this message translates to:
  /// **'The file as it was opened'**
  String get versionOpenedDetail;

  /// Version history: a save.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get versionSaved;

  /// Version history: a save with a new signature.
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get versionSigned;

  /// Version history: unsaved work kept before a restore.
  ///
  /// In en, this message translates to:
  /// **'Unsaved work'**
  String get versionUnsavedWork;

  /// Version history: a restore.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get versionRestored;

  /// Version history: a version's line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} edit} other{{n} edits}}'**
  String versionEdits(int count, String n);

  /// Version history: a version's line; {names} lists the edits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} edit · {names}} other{{n} edits · {names}}}'**
  String versionEditsNamed(int count, String n, String names);

  /// Version history: the preview's bar; {time} is a time or a date.
  ///
  /// In en, this message translates to:
  /// **'Viewing the version from {time}.'**
  String versionViewing(String time);

  /// Version history: the preview's bar.
  ///
  /// In en, this message translates to:
  /// **'Read-only. Your current document is unchanged.'**
  String get versionReadOnly;

  /// Version history: leaves the preview.
  ///
  /// In en, this message translates to:
  /// **'Back to current'**
  String get versionBack;

  /// Version history: the preview bar's restore.
  ///
  /// In en, this message translates to:
  /// **'Restore this version…'**
  String get versionRestoreThis;

  /// Version history: the chosen row's restore.
  ///
  /// In en, this message translates to:
  /// **'Restore…'**
  String get versionRestoreShort;

  /// Version history: compare (P3).
  ///
  /// In en, this message translates to:
  /// **'Compare with current'**
  String get versionCompare;

  /// Version history: the restore question's title.
  ///
  /// In en, this message translates to:
  /// **'Restore the version from {time}?'**
  String versionRestoreTitle(String time);

  /// Version history: the restore question (decision 27).
  ///
  /// In en, this message translates to:
  /// **'Your current file, with any unsaved edits, is kept as a version first, so nothing is lost.'**
  String get versionRestoreBody;

  /// Version history: the restore question's button.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get versionRestore;

  /// The command palette as a command (a11-3, a11-1j) and the palette's accessible name (a11-2).
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get commandPalette;

  /// The command that shows the cheat sheet (a11-1j, a11-3).
  ///
  /// In en, this message translates to:
  /// **'Show keyboard shortcuts'**
  String get commandShowShortcuts;

  /// The Save a copy command in the palette, the cheat sheet and Settings › Keyboard shortcuts (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Save a copy'**
  String get commandSaveCopy;

  /// The command that shows the document's properties (a2-7) in the palette and the shortcut lists.
  ///
  /// In en, this message translates to:
  /// **'Document properties'**
  String get commandDocumentProperties;

  /// The command that moves to the next open document (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Next document'**
  String get commandNextDocument;

  /// The commands that show the first nine open documents (a1-10). {number} is 1 to 9 formatted for the region.
  ///
  /// In en, this message translates to:
  /// **'Show document {number}'**
  String commandShowDocument(String number);

  /// The Go to page command (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get commandGoToPage;

  /// The Reading mode command (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get commandReadingMode;

  /// Organize: the command that inserts pages from a file (a14-1d).
  ///
  /// In en, this message translates to:
  /// **'Insert from file'**
  String get commandInsertFromFile;

  /// Organize: the command that deletes the selected pages (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Delete pages'**
  String get commandDeletePages;

  /// Organize: the command that selects every page (a14-1d).
  ///
  /// In en, this message translates to:
  /// **'Select all pages'**
  String get commandSelectAllPages;

  /// Organize: the command that moves the selected pages up (a14-1d).
  ///
  /// In en, this message translates to:
  /// **'Move pages up'**
  String get commandMovePagesUp;

  /// Organize: the command that moves the selected pages down.
  ///
  /// In en, this message translates to:
  /// **'Move pages down'**
  String get commandMovePagesDown;

  /// The window's system menu, as a shortcut (Alt+Space on Windows).
  ///
  /// In en, this message translates to:
  /// **'Window menu'**
  String get commandWindowMenu;

  /// The command that closes the window, as a shortcut (Alt+F4).
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get commandCloseWindow;

  /// The command that quits the app, as a shortcut (⌘Q, Ctrl+Q).
  ///
  /// In en, this message translates to:
  /// **'Quit Ferman'**
  String get commandQuit;

  /// Command palette: the search field's placeholder and name (a11-2).
  ///
  /// In en, this message translates to:
  /// **'Search commands, pages and text'**
  String get palettePlaceholder;

  /// Command palette: no match while a document is open (a11-2 note). {query} is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'No commands match “{query}”. Press Enter to search the document instead.'**
  String paletteEmpty(String query);

  /// Command palette: no match on the start screen, where there is no document to search. {query} is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'No commands match “{query}”.'**
  String paletteEmptyNoDocument(String query);

  /// Command palette: the group of commands (a11-2).
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get paletteCommands;

  /// Command palette: the group of recent files (a11-2).
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get paletteRecentFiles;

  /// Command palette footer: after ↑ ↓, moving between commands.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get paletteMove;

  /// Command palette footer: after ↵, running the command.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get paletteRun;

  /// Cheat sheet: the search field's placeholder and name (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Search shortcuts'**
  String get shortcutsSheetSearch;

  /// Cheat sheet: the note under the groups (a11-3).
  ///
  /// In en, this message translates to:
  /// **'Change shortcuts in Settings › Keyboard shortcuts.'**
  String get shortcutsSheetNote;

  /// Cheat sheet and Settings › Keyboard shortcuts: the mark on a shortcut the user changed (a11-3 note).
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get shortcutsChanged;

  /// Cheat sheet and Settings › Keyboard shortcuts: no match. {query} is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'No shortcuts match “{query}”.'**
  String shortcutsNoMatch(String query);

  /// Cheat sheet: the group of general commands (a11-3 GENERAL), shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get shortcutsGroupGeneral;

  /// Cheat sheet: the group of navigation commands (a11-3 NAVIGATE), shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get shortcutsGroupNavigate;

  /// Cheat sheet: the group of window commands (a11-3 WINDOW), shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get shortcutsGroupWindow;

  /// Settings › Keyboard shortcuts: the search field's placeholder and name (a11-1j).
  ///
  /// In en, this message translates to:
  /// **'Search commands or press keys'**
  String get shortcutsPaneSearch;

  /// Settings › Keyboard shortcuts: the preset menu's name (a11-1j).
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get shortcutsPreset;

  /// Settings › Keyboard shortcuts: the preset with Ferman's own keys (a11-1j).
  ///
  /// In en, this message translates to:
  /// **'Ferman (default)'**
  String get shortcutsPresetFerman;

  /// Settings › Keyboard shortcuts: the preset with Acrobat's keys (a11-1j).
  ///
  /// In en, this message translates to:
  /// **'Like Acrobat'**
  String get shortcutsPresetAcrobat;

  /// Settings › Keyboard shortcuts: the preset with macOS Preview's keys (a11-1j).
  ///
  /// In en, this message translates to:
  /// **'Like Preview'**
  String get shortcutsPresetPreview;

  /// Settings › Keyboard shortcuts: a row waiting for keys (a11-1j).
  ///
  /// In en, this message translates to:
  /// **'Press new shortcut…'**
  String get shortcutsRecording;

  /// Settings › Keyboard shortcuts: the keys pressed belong to another command (a11-1j). {keys} and {current} are key caps such as ⌥⌘S; {command} is the other command's name.
  ///
  /// In en, this message translates to:
  /// **'{keys} is already “{command}”. Press Enter to reassign it, Esc to keep {current}.'**
  String shortcutsTaken(String keys, String command, String current);

  /// Settings › Keyboard shortcuts: as shortcutsTaken, for a command that has no shortcut now.
  ///
  /// In en, this message translates to:
  /// **'{keys} is already “{command}”. Press Enter to reassign it, Esc to keep no shortcut.'**
  String shortcutsTakenNone(String keys, String command);

  /// Settings › Keyboard shortcuts: the keys pressed cannot be given to a command (M4 decision 33). {keys} are key caps.
  ///
  /// In en, this message translates to:
  /// **'{keys} belongs to the system. Press other keys, or Esc to cancel.'**
  String shortcutsReserved(String keys);

  /// Settings › Keyboard shortcuts and the cheat sheet: a command left without keys (M4 decision 33).
  ///
  /// In en, this message translates to:
  /// **'No shortcut'**
  String get shortcutsNone;

  /// Settings › Keyboard shortcuts: a row's key button, for screen readers. {command} is the command's name.
  ///
  /// In en, this message translates to:
  /// **'Change the shortcut of {command}'**
  String shortcutsChange(String command);

  /// Settings › Keyboard shortcuts: the button on a changed row that gives the command its default keys back.
  ///
  /// In en, this message translates to:
  /// **'Restore the default shortcut'**
  String get shortcutsReset;

  /// Settings search (a11-1, G50): title of the empty state when no pane matches.
  ///
  /// In en, this message translates to:
  /// **'No settings match'**
  String get settingsSearchNoMatch;

  /// Settings search and Settings › Licences: body of the empty state when nothing matches.
  ///
  /// In en, this message translates to:
  /// **'Try another word.'**
  String get settingsSearchNoMatchBody;

  /// The last row of the settings pane list and its heading: the third-party notices (M4 plan question 7; a11-5 names its button so).
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get settingsPaneLicences;

  /// Settings › Editing › Keep versions (a11-1c): the option that keeps none.
  ///
  /// In en, this message translates to:
  /// **'Don’t keep versions'**
  String get settingsKeepVersionsOff;

  /// Settings › Fonts (a11-1d): placeholder of the search field; {count} is the number of families, formatted.
  ///
  /// In en, this message translates to:
  /// **'Search {count} installed fonts'**
  String settingsFontsSearch(String count);

  /// Settings › Fonts (a11-1d): screen-reader name of the search field.
  ///
  /// In en, this message translates to:
  /// **'Search fonts'**
  String get settingsFontsSearchLabel;

  /// Settings › Fonts (a11-1d): screen-reader name of the filter select.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get settingsFontsFilter;

  /// Settings › Fonts (a11-1d): filter option, the fonts that draw every Turkish letter.
  ///
  /// In en, this message translates to:
  /// **'Covers Turkish'**
  String get settingsFontsFilterTurkish;

  /// Settings › Fonts (a11-1d): filter option.
  ///
  /// In en, this message translates to:
  /// **'All fonts'**
  String get settingsFontsFilterAll;

  /// Settings › Fonts (a11-1d): filter option, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Used in open documents'**
  String get settingsFontsFilterOpen;

  /// Settings › Fonts (a11-1d): where a font comes from, under its name.
  ///
  /// In en, this message translates to:
  /// **'Included with Ferman'**
  String get settingsFontsBundled;

  /// Settings › Fonts (a11-1d): where a font comes from, under its name: installed on this computer.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get settingsFontsInstalled;

  /// Settings › Fonts (a11-1d): the legend of the coverage chips. The codes stay in Latin letters.
  ///
  /// In en, this message translates to:
  /// **'TR Turkish · LX Latin Extended · CY Cyrillic · GR Greek · AR Arabic · HE Hebrew · DV Devanagari · CJK Chinese, Japanese, Korean. A struck-through code means the font can’t draw that script.'**
  String get settingsFontsLegend;

  /// Settings › Fonts (a11-1d): tooltip of a coverage chip; {script} is its code, such as TR.
  ///
  /// In en, this message translates to:
  /// **'Covers {script}'**
  String settingsFontsCovers(String script);

  /// Settings › Fonts (a11-1d): tooltip of a struck-through coverage chip; {script} is its code.
  ///
  /// In en, this message translates to:
  /// **'Doesn’t cover {script}'**
  String settingsFontsMissing(String script);

  /// Settings › Fonts (a11-1d): title of the empty state when no font matches the search and filter.
  ///
  /// In en, this message translates to:
  /// **'No fonts match'**
  String get settingsFontsNoMatch;

  /// Settings › Fonts (a11-1d): screen-reader name of the spinner while the fonts are read.
  ///
  /// In en, this message translates to:
  /// **'Reading the fonts on this computer…'**
  String get settingsFontsLoading;

  /// Settings › Signatures and certificates (a11-1e): label of the saved signatures.
  ///
  /// In en, this message translates to:
  /// **'Saved signatures · on this device only'**
  String get settingsSavedSignatures;

  /// Settings › Signatures and certificates (a11-1e): shown when nothing is saved.
  ///
  /// In en, this message translates to:
  /// **'No saved signatures yet. Fill & Sign › Sign makes one.'**
  String get settingsSavedSignaturesNone;

  /// Settings › Signatures and certificates (a11-1e): under a typed saved signature.
  ///
  /// In en, this message translates to:
  /// **'Typed'**
  String get settingsSignatureTyped;

  /// Settings › Signatures and certificates: tooltip and screen-reader name of a saved signature’s delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete saved signature'**
  String get settingsDeleteSignature;

  /// Settings › Signatures and certificates (a11-1e): label of the certificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get settingsCertificates;

  /// Settings › Signatures and certificates (a11-1e): button, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Add certificate file…'**
  String get settingsAddCertificate;

  /// Settings › Signatures and certificates (a11-1e): select, disabled in this version. e-imza is the Turkish name of the qualified signature.
  ///
  /// In en, this message translates to:
  /// **'e-imza card driver (PKCS#11)'**
  String get settingsCardDriver;

  /// Settings › Signatures and certificates (a11-1e): the card driver select’s option.
  ///
  /// In en, this message translates to:
  /// **'Find automatically'**
  String get settingsCardDriverAuto;

  /// Settings › Signatures and certificates (a11-1e): select, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Timestamp server'**
  String get settingsTimestampServer;

  /// Settings › Signatures and certificates (a11-1e): the timestamp server select’s option while nothing connects.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsTimestampNone;

  /// Settings › Signatures and certificates (a11-1e): switch, off and disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Check revocation online when opening signed files'**
  String get settingsCheckRevocation;

  /// Settings › Advanced (a11-1k): switch, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Use the graphics card to draw pages'**
  String get settingsGpu;

  /// Settings › Advanced (a11-1k): select of the memory kept for drawn pages.
  ///
  /// In en, this message translates to:
  /// **'Page cache'**
  String get settingsPageCache;

  /// Settings › Advanced (a11-1k): select.
  ///
  /// In en, this message translates to:
  /// **'Thumbnails'**
  String get settingsThumbnails;

  /// Settings › Advanced (a11-1k): thumbnails option.
  ///
  /// In en, this message translates to:
  /// **'Make as needed'**
  String get settingsThumbnailsAuto;

  /// Settings › Advanced (a11-1k): thumbnails option, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Make all when opening'**
  String get settingsThumbnailsAll;

  /// Settings › Advanced (a11-1k): switch, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Show the PDF object inspector (for developers)'**
  String get settingsObjectInspector;

  /// Settings › Advanced (a11-1k): button; opens the system save panel.
  ///
  /// In en, this message translates to:
  /// **'Export settings…'**
  String get settingsExport;

  /// Settings › Advanced (a11-1k): button; opens the system open panel.
  ///
  /// In en, this message translates to:
  /// **'Import settings…'**
  String get settingsImport;

  /// Settings › Advanced (a11-1k): button, disabled in this version.
  ///
  /// In en, this message translates to:
  /// **'Show log files'**
  String get settingsShowLogs;

  /// Settings › Advanced (a11-1k): the danger box’s text.
  ///
  /// In en, this message translates to:
  /// **'Reset every setting to its default. Saved signatures and certificates stay.'**
  String get settingsReset;

  /// Settings › Advanced (a11-1k): the danger button; asks first.
  ///
  /// In en, this message translates to:
  /// **'Reset settings…'**
  String get settingsResetButton;

  /// Settings › Advanced: title of the reset confirmation (G50).
  ///
  /// In en, this message translates to:
  /// **'Reset every setting?'**
  String get settingsResetTitle;

  /// Settings › Advanced: body of the reset confirmation (G50).
  ///
  /// In en, this message translates to:
  /// **'Theme, language, region and every other choice go back to their defaults. Saved signatures, your stamps and the documents you have open stay.'**
  String get settingsResetBody;

  /// Settings › Advanced: the reset confirmation’s danger button.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetConfirm;

  /// Settings › Advanced: title of the import confirmation (G50).
  ///
  /// In en, this message translates to:
  /// **'Replace your settings?'**
  String get settingsImportTitle;

  /// Settings › Advanced: body of the import confirmation (G50).
  ///
  /// In en, this message translates to:
  /// **'The settings in the file replace yours. Saved signatures and the documents you have open stay.'**
  String get settingsImportBody;

  /// Settings › Advanced: the import confirmation’s button.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImportConfirm;

  /// Settings › Advanced: toast title when the chosen file is not a settings file (G50).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t import the settings'**
  String get settingsImportFailed;

  /// Settings › Advanced: toast text when the chosen file is not a settings file.
  ///
  /// In en, this message translates to:
  /// **'The file isn’t a Ferman settings file.'**
  String get settingsImportFailedBody;

  /// Settings › Advanced: toast after Export settings….
  ///
  /// In en, this message translates to:
  /// **'Settings exported'**
  String get settingsExported;

  /// Settings › Advanced: toast when the file could not be written.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t export the settings'**
  String get settingsExportFailed;

  /// Settings › Advanced: the file name the save panel suggests, without its extension .json.
  ///
  /// In en, this message translates to:
  /// **'Ferman settings'**
  String get settingsExportName;

  /// Settings › Advanced: the open panel’s filter name for Import settings….
  ///
  /// In en, this message translates to:
  /// **'Settings file'**
  String get settingsSettingsFile;

  /// Settings › Licences: the first line (G13: the licence is Apache-2.0).
  ///
  /// In en, this message translates to:
  /// **'Ferman is free software under the Apache License 2.0. It is built on the work below, and each part keeps its own licence.'**
  String get licencesIntro;

  /// Settings › Licences: placeholder and screen-reader name of the search field.
  ///
  /// In en, this message translates to:
  /// **'Search licences'**
  String get licencesSearch;

  /// Settings › Licences: screen-reader name of the spinner while the licences are read.
  ///
  /// In en, this message translates to:
  /// **'Reading the licences…'**
  String get licencesLoading;

  /// Settings › Licences: title of the empty state when the search finds nothing.
  ///
  /// In en, this message translates to:
  /// **'No licences match'**
  String get licencesNoMatch;

  /// Heading of the page-badge legend the Pages tab's info button opens (f5, FmSidebar).
  ///
  /// In en, this message translates to:
  /// **'Page badges'**
  String get sidebarLegendTitle;

  /// Legend row name (f5): the accent dot of a page changed since the document was opened.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get sidebarLegendEdited;

  /// Legend row explanation after sidebarLegendEdited (f5), lowercase as it follows a dot.
  ///
  /// In en, this message translates to:
  /// **'changed since you opened it'**
  String get sidebarLegendEditedBody;

  /// Legend row name (f5): the comment badge.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get sidebarLegendComments;

  /// Legend row explanation after sidebarLegendComments (f5).
  ///
  /// In en, this message translates to:
  /// **'notes or markup on the page'**
  String get sidebarLegendCommentsBody;

  /// Legend row name (f5): the form-field badge.
  ///
  /// In en, this message translates to:
  /// **'Form fields'**
  String get sidebarLegendFields;

  /// Legend row explanation after sidebarLegendFields (f5).
  ///
  /// In en, this message translates to:
  /// **'fields you can fill in'**
  String get sidebarLegendFieldsBody;

  /// Legend row name (f5): the signature badge.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get sidebarLegendSignature;

  /// Legend row explanation after sidebarLegendSignature (f5).
  ///
  /// In en, this message translates to:
  /// **'signed or has a signature field'**
  String get sidebarLegendSignatureBody;

  /// Legend row name (f5): the amber warning badge.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get sidebarLegendWarnings;

  /// Legend row explanation after sidebarLegendWarnings (f5).
  ///
  /// In en, this message translates to:
  /// **'missing glyphs, overflow, broken links'**
  String get sidebarLegendWarningsBody;

  /// Note under the legend's rows (f5).
  ///
  /// In en, this message translates to:
  /// **'Screen readers hear badges in the page name, e.g. “Page 1, edited, 2 comments, 1 warning”.'**
  String get sidebarLegendFootnote;

  /// Tooltip and spoken name of a thumbnail's edited dot (f5); it follows the page name after a comma.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get sidebarBadgeEdited;

  /// Tooltip and spoken name of a thumbnail's comment badge (f5).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{n} comments}}'**
  String sidebarBadgeComments(int count, String n);

  /// Tooltip and spoken name of a thumbnail's form-field badge (f5).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 form field} other{{n} form fields}}'**
  String sidebarBadgeFields(int count, String n);

  /// Tooltip and spoken name of a thumbnail's signature badge on a signed page (f5).
  ///
  /// In en, this message translates to:
  /// **'signed'**
  String get sidebarBadgeSigned;

  /// Tooltip and spoken name of a thumbnail's signature badge on a page with an empty signature field (f5).
  ///
  /// In en, this message translates to:
  /// **'signature field'**
  String get sidebarBadgeSignatureField;

  /// Title of a bookmark Add bookmark (⌘B) adds, renamed in place at once (a2-3a).
  ///
  /// In en, this message translates to:
  /// **'New bookmark'**
  String get outlineNewBookmark;

  /// Accessible name of the field that renames a bookmark in place (a2-3a, FmSidebar).
  ///
  /// In en, this message translates to:
  /// **'Bookmark name'**
  String get outlineBookmarkName;

  /// The history step of an outline change: rename, add, nest, reorder or delete (a2-3a).
  ///
  /// In en, this message translates to:
  /// **'Change bookmarks'**
  String get outlineStep;

  /// Outline › More menu item: renames the selected bookmark in place (F2).
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get outlineRename;

  /// Outline › More menu item: moves the selected bookmark one level in.
  ///
  /// In en, this message translates to:
  /// **'Nest under the one above'**
  String get outlineNest;

  /// Outline › More menu item: moves the selected bookmark one level out.
  ///
  /// In en, this message translates to:
  /// **'Move out a level'**
  String get outlineUnnest;

  /// Outline › More menu item: swaps the selected bookmark with the one above at its level.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get outlineMoveUp;

  /// Outline › More menu item: swaps the selected bookmark with the one below at its level.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get outlineMoveDown;

  /// Outline › More menu item: deletes the selected bookmark and the ones nested in it.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get outlineDelete;

  /// The history step of a metadata change in Document properties (a2-7).
  ///
  /// In en, this message translates to:
  /// **'Change document properties'**
  String get propertiesStep;

  /// Line under dropOverlayCombine (a1-6, FmStart dropCombineSub): the files go to Combine's tab, where they can be reordered.
  ///
  /// In en, this message translates to:
  /// **'Merged in the order shown. You can reorder before saving.'**
  String get dropOverlayCombineDescription;
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
