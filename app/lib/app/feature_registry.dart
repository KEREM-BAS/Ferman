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
///   icon: IconName.filePlus2,
///   disabledReason: Feature.createPdf.disabledReason(context),
///   child: Text(l10n.startCreatePdf),
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

  /// Creating a PDF: Start › Create PDF, the drop zone's New blank PDF and
  /// Convert › Create PDF.
  createPdf('B019'),

  /// Combining and splitting files: Start › Combine files and Organize ›
  /// Split, Combine files.
  combineAndSplit('B020'),

  /// Scan to PDF: Start › Scan to PDF and Convert › Scan.
  scanToPdf('B021'),

  /// Showing every open document at once: "+N" › Show all open documents
  /// (a1-10).
  showAllDocuments('B117'),

  /// Closing documents: the close button of the active clean tab.
  closingDocuments('B029'),

  /// Saving: the mode bar's Save while a document has unsaved changes.
  saving('B031'),

  // Viewing.

  /// Rendering pages on the canvas.
  pageRendering('B069'),

  /// The Select and Hand tools of the View row.
  selectAndHand('B033'),

  /// Zoom: the View row's marquee zoom, zoom buttons, zoom menu and Fit,
  /// the status bar's zoom buttons and Settings › General › Zoom.
  zoom('B034'),

  /// Page layout: the View row's control and Settings › General › Page
  /// layout for new documents.
  pageLayout('B035'),

  /// Split view (View row).
  splitView('B036'),

  /// Read aloud (View row).
  readAloud('B037'),

  /// Presentation mode (View row › Present).
  presentation('B038'),

  /// Dark reading mode: the View row's switch and the option under
  /// Settings › General › PDF pages in dark theme.
  darkReadingMode('B040'),

  /// How PDF pages look in the dark theme: Paper white and Dimmed under
  /// Settings › General.
  pageLookInDarkTheme('B078'),

  /// Page navigation: the status bar's Previous page and Next page.
  pageNavigation('B070'),

  /// The sidebar's tab contents: the Pages tab's badge legend.
  sidebarContents('B065'),

  /// Editing bookmarks: the Outline tab's Add bookmark and More.
  editingBookmarks('B066'),

  /// Attaching files: the Attachments tab's Attach a file.
  attachingFiles('B067'),

  /// Saving an attachment: the Attachments tab's Save attachment as….
  savingAttachments('B110'),

  /// Showing and hiding layers in a repaired document, or one opened with
  /// its password: the Layers tab's eye buttons there.
  layerVisibility('B111'),

  /// The right panel's sections: its More button.
  rightPanelSections('B068'),

  /// Reopening the documents from last time (Settings › General).
  reopenDocuments('B079'),

  /// Making Ferman the default PDF app on macOS (Settings › General).
  defaultAppMacos('B080'),

  /// Making Ferman the default PDF app on Windows (Settings › General).
  defaultAppWindows('B101'),

  /// Making Ferman the default PDF app on Linux (Settings › General).
  defaultAppLinux('B102'),

  // Editing.

  /// Editing text: Edit › Edit text and the first-run tile "Edit text and
  /// images".
  editingText('B041'),

  /// Adding text boxes (Edit › Add text).
  addingTextBoxes('B042'),

  /// Adding images (Edit › Add image).
  addingImages('B043'),

  /// Links (Edit › Link).
  links('B044'),

  /// Find and replace (Edit › Find & replace).
  findAndReplace('B045'),

  /// Regular expressions in search: the find bar's toggle and option.
  searchRegex('B113'),

  /// Searching comments, form fields and bookmarks: the find bar's Look in
  /// options and a2-4d's action.
  searchScopes('B114'),

  /// Page marks: watermark, header and footer, Bates numbering and page
  /// background (Edit › Page marks).
  pageMarks('B046'),

  /// Undo, redo and the edit history (Edit row).
  undoAndHistory('B047'),

  /// Edit marks (Edit › Mark edited text).
  editMarks('B048'),

  /// The review list of edits (Edit › Review edits).
  editReview('B049'),

  // Comments, forms and signatures.

  /// Comments and annotations: the Comment row's tools but Measure, its
  /// colours and Show comments.
  comments('B050'),

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

  /// Organizing pages: the Organize row's Insert, rotations, Duplicate,
  /// Extract, Replace, Delete, Crop and Page labels.
  organizingPages('B056'),

  // Convert.

  /// Converting PDFs to other formats: Start › Convert, the Convert row's
  /// formats and the first-run tile "Convert to and from Office".
  convertFromPdf('B023'),

  /// Text recognition: Start › Recognize text (OCR), Convert › Recognize
  /// text, the first-run tile, Settings › Text recognition and Settings ›
  /// Privacy › Downloads you start.
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

  /// Compress: Start › Compress and Tools › Compress.
  compress('B022'),

  /// Compare: Start › Compare, Tools › Compare and the first-run tile.
  compare('B027'),

  /// Accessibility tools: Tools › Accessibility and the first-run tile.
  accessibilityTools('B062'),

  /// PDF/A and preflight (Tools row).
  pdfAAndPreflight('B063'),

  /// Batch actions: Tools › Batch actions and the first-run tile.
  batchActions('B064'),

  /// Basic system print (Tools › Print).
  printing('B061'),

  /// Version history (Tools › Version history).
  versionHistory('B060'),

  /// The AI assistant: the mode bar's AI button, Tools › AI assistant,
  /// Settings › AI assistant and Settings › Privacy › Your AI provider.
  aiAssistant('B032'),

  /// The command palette: the title bar's Search.
  commandPalette('B030'),

  // Settings and first run.

  /// Searching Settings.
  settingsSearch('B073'),

  /// Settings › Editing.
  settingsEditing('B074'),

  /// Settings › Fonts.
  settingsFonts('B075'),

  /// Keyboard shortcuts: Settings › Keyboard shortcuts.
  keyboardShortcuts('B076'),

  /// Settings › Advanced.
  settingsAdvanced('B077'),

  /// Choosing document languages (Settings › Language and region › Add).
  documentLanguages('B081'),

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
