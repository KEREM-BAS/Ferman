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
