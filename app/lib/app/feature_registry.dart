import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:flutter/widgets.dart';

/// The feature registry (ROADMAP gate S9): the features that are visible
/// but do not work yet. Every entry point of one names its value here and
/// takes its disabled state and its reason from it.
///
/// A control of such a feature stays visible exactly as designed,
/// disabled, with the localized "Available in a future version" (G10):
///
/// ```dart
/// Button(
///   icon: IconName.scan,
///   disabledReason: Feature.scanToPdf.disabledReason(context),
///   child: Text(l10n.startScanToPdf),
/// )
/// ```
///
/// Each value names the `docs/BACKLOG.md` row that tracks it ([backlog]),
/// which stays open while the value exists. A feature ships by leaving
/// the registry: deleting its value turns every control that still names
/// it into a compile error, so none is left disabled, or enabled without
/// its handler, by mistake; its row moves to Done in the same commit. A
/// feature whose entry points ship at different times is split into one
/// value and one row per part first.
///
/// `tools/checks` `feature_registry` fails when a value has no open row (a
/// row under Done means the feature shipped and the value must go), when a
/// value names no control, and when a screen passes the future-version
/// reason without this registry.
///
/// Keyboard commands of these features are disabled by having no handler
/// in the shortcut table (`ShellCommandAction`); BACKLOG lists them as
/// "keys only".
enum Feature {
  // Files and documents.

  /// Opening files in the web build, whose engine is a stub: the title
  /// bar's "+", ⌘O or Ctrl+O, Start › Open file… and Open a PDF.
  openFilesOnWeb('B116'),

  /// The phone's file browser: the navigation bar's Files.
  phoneFiles('B168'),

  /// The phone home's search: its field and the app bar's Search.
  phoneSearch('B170'),

  /// The phone's menus: the app bar's More and a recent file's More.
  phoneMoreMenus('B171'),

  /// The phone home's places to open from.
  phoneOpenFrom('B172'),

  /// Editing on the phone: the phone home's quick tool Edit.
  phoneEditing('B173'),

  /// About and the licences: the phone's Settings › About and licence
  /// (a13-15).
  aboutAndLicence('B169'),

  /// Combining dropped files: "Combine into one PDF" while files are dragged
  /// over the window (a1-6).
  combineDropped('B191'),

  /// Create PDF from the clipboard: its source in the Create PDF dialog.
  createFromClipboard('B176'),

  /// Word and Excel as input: a row of Combine's list, and the not-a-PDF
  /// tab's Convert to PDF.
  officeInputs('B175'),

  /// Combine on the phone, which has no shell yet: the phone home's quick tool.
  phoneCombine('B195'),

  /// Scan to PDF: Start › Scan to PDF and Convert › Scan.
  scanToPdf('B021'),

  /// The Save as sheet's options "Include comments and markup" and "Remove
  /// edit history from the file" (a1-11).
  saveAsOptions('B138'),

  // Viewing.

  /// Split view (View row).
  splitView('B036'),

  /// Read aloud (View row).
  readAloud('B037'),

  /// Presentation mode (View row › Present).
  presentation('B038'),

  /// Dark reading mode: the View row's switch and the option under
  /// Settings › General › PDF pages in dark theme.
  darkReadingMode('B040'),

  /// The sidebar's tab contents: the Pages tab's badge legend.
  sidebarContents('B065'),

  /// Editing bookmarks: the Outline tab's Add bookmark and More.
  editingBookmarks('B066'),

  /// Attaching files: the Attachments tab's Attach a file.
  attachingFiles('B067'),

  /// Showing and hiding layers in a repaired document, or one opened with
  /// its password: the Layers tab's eye buttons there.
  layerVisibility('B111'),

  /// The right panel's sections: its More button.
  rightPanelSections('B068'),

  /// Making Ferman the default PDF app on Windows (Settings › General).
  defaultAppWindows('B101'),

  /// Making Ferman the default PDF app on Linux (Settings › General).
  defaultAppLinux('B102'),

  // Editing.

  /// Adding text boxes: Edit › Add text and Settings › Editing › Font for
  /// new text.
  addingTextBoxes('B042'),

  /// Adding images (Edit › Add image).
  addingImages('B043'),

  /// A link to a file: a3-6's File type.
  linksToFiles('B200'),

  /// Find and replace (Edit › Find & replace).
  findAndReplace('B045'),

  /// Regular expressions in search: the find bar's toggle and option.
  searchRegex('B113'),

  /// Searching comments and form fields: the find bar's Look in options
  /// Comments and Form fields, and a2-4d's action.
  searchScopes('B128'),

  /// Page marks: watermark, header and footer, Bates numbering and page
  /// background (Edit › Page marks).
  pageMarks('B046'),

  /// The font picker's "Whole block" scope: the whole block in the chosen
  /// font, not only its missing characters (a3-3b).
  fontScopeWholeBlock('B137'),

  // Comments, forms and signatures.

  /// Stamps: Comment › Stamp and its library (a4-3, a4-3b).
  stamps('B014'),

  /// Flatten comments: the Comments panel's More › Flatten (a4-5b).
  flattenComments('B198'),

  /// Measure and calibrate: Comment › Measure and Tools › Measure.
  measure('B051'),

  /// Form filling: Fill & Sign › Fill fields, Add text, Checkmark and Date,
  /// and the first-run tile "Fill and sign forms".
  formFilling('B052'),

  /// Simple signatures: Start › Sign, Fill & Sign › Sign and Initials, and
  /// Settings › Signatures and certificates.
  simpleSignatures('B024'),

  /// Certificate signatures: Fill & Sign › Digital signature, Settings ›
  /// Privacy › Timestamps and the first-run tile "e-imza and digital
  /// signatures".
  certificateSignatures('B053'),

  /// Turkish e-imza (Fill & Sign › e-imza).
  eImza('B054'),

  /// Preparing forms (Fill & Sign › Prepare form).
  preparingForms('B055'),

  // Pages.

  // Convert.

  /// Converting PDFs to other formats: Start › Convert, the Convert row's
  /// formats and the first-run tile "Convert to and from Office".
  convertFromPdf('B023'),

  /// Text recognition: Start › Recognize text (OCR), Convert › Recognize
  /// text, the first-run tile, Settings › Text recognition, Settings ›
  /// Privacy › Downloads you start, the Search results tab's "No text to
  /// search" and the Edit panel's callout on a scanned page (a3-11).
  ocr('B025'),

  // Protect.

  /// Password protection and permissions: Start › Protect and Protect ›
  /// Password.
  passwordProtection('B026'),

  /// Redaction: Protect › Redact, Find & redact and Apply redactions, and
  /// the first-run tile.
  redaction('B057'),

  /// Removing hidden information (Protect row).
  removeHiddenInformation('B058'),

  /// The security report (Protect row).
  securityReport('B059'),

  // Tools.

  /// Compress: Start › Compress and Tools › Compress, and the Save as
  /// sheet's "Optimized for web", which needs its image pipeline (G111).
  compress('B022'),

  /// Compare: Start › Compare, Tools › Compare, the first-run tile and the
  /// changed-on-disk bar's Compare (a11-7b).
  compare('B027'),

  /// Accessibility tools: Tools › Accessibility and the first-run tile.
  accessibilityTools('B062'),

  /// PDF/A and preflight: the Tools row and the Save as sheet's "PDF/A-2b,
  /// for archiving" (G111).
  pdfAAndPreflight('B063'),

  /// Batch actions: Tools › Batch actions and the first-run tile.
  batchActions('B064'),

  /// Basic system print (Tools › Print).
  printing('B061'),

  /// Version history: Tools › Version history and Settings › Editing › Keep
  /// versions.
  versionHistory('B060'),

  /// The AI assistant: the mode bar's AI button, Tools › AI assistant,
  /// Settings › AI assistant and Settings › Privacy › Your AI provider.
  aiAssistant('B032'),

  /// The command palette: the title bar's Search.
  commandPalette('B030'),

  // Settings and first run.

  /// Searching Settings.
  settingsSearch('B073'),

  /// Settings › Fonts.
  settingsFonts('B075'),

  /// Keyboard shortcuts: Settings › Keyboard shortcuts.
  keyboardShortcuts('B076'),

  /// Settings › Advanced.
  settingsAdvanced('B077'),

  /// Spacing before and after a block in the text panel (a3-2): Spacing ›
  /// Before and After.
  blockSpacingAround('B160'),

  /// Reset text style in the text panel's heading (a3-2).
  blockStyleReset('B162'),

  /// Choosing document languages (Settings › Language and region › Add).
  documentLanguages('B081'),

  /// Check spelling and Hyphenate in the Edit panel's Language section.
  spellCheck('B150'),

  /// The update check: Settings › Updates and Settings › Privacy › Check
  /// for updates.
  updateCheck('B082'),

  /// Signature checks (revocation lookups) under Settings › Privacy.
  signatureChecks('B083'),

  /// The network activity log (Settings › Privacy › Show network
  /// activity…).
  networkActivityLog('B084'),

  /// Community translation: first run's "Help translate Ferman".
  communityTranslation('B085'),

  /// The "Source code" and "Support the project" links of first run.
  projectLinks('B086');

  new(this.backlog);

  /// The id of the `docs/BACKLOG.md` row that tracks the feature, such as
  /// `B018`.
  final String backlog;

  /// The reason the controls of this feature show while disabled: the
  /// localized "Available in a future version".
  String disabledReason(BuildContext context) => futureVersionReason(context);
}
