// GENERATED — do not edit; run (cd tools/l10n && dart run l10n)
//
// From the abstract members of app/lib/l10n/gen/app_localizations.dart, the
// gen-l10n output: run it after `flutter gen-l10n`. `dart run l10n --check`
// (in CI) fails while this file is stale (tools/l10n/README.md).

import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The English strings, each wrapped in U+2066 LEFT-TO-RIGHT ISOLATE and
/// U+2069 POP DIRECTIONAL ISOLATE ([isolate]), for a right-to-left app
/// language without a translation (Persian and Hebrew today, G93).
///
/// Such a language mirrors the UI while its strings fall back to English
/// (G20). In a right-to-left paragraph an English string's numbers and
/// neutral characters would move: "1 of 2" would read "of 2 1" and "Open
/// file…" "…Open file". Inside the isolate each string keeps its own
/// left-to-right order, and the paragraph still places it at the start
/// (the right). Placeholder values keep their own direction: a language's
/// own name in Arabic or Hebrew script reads right to left inside the
/// isolate. Strings that already hold isolates (values in `bidiIsolate`)
/// nest correctly.
///
/// `FermanApp` installs it through [localizationsDelegates] while
/// `AppLanguage.isolatesFallbackStrings` holds; English, Turkish and Arabic
/// never see it. It overrides every message of [AppLocalizations] and wraps
/// [AppLocalizationsEn]'s text.
final class IsolatedFallbackLocalizations extends AppLocalizationsEn {
  /// The English strings, isolated.
  new();

  /// Loads [IsolatedFallbackLocalizations] for English, synchronously.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _IsolatedFallbackLocalizationsDelegate();

  /// [delegate], then the app's own delegates. `Localizations` loads the
  /// first delegate of each type that supports the locale, so [delegate]
  /// replaces [AppLocalizations.delegate].
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    ...AppLocalizations.localizationsDelegates,
  ];

  /// [text] between U+2066 LEFT-TO-RIGHT ISOLATE and U+2069 POP DIRECTIONAL
  /// ISOLATE.
  static String isolate(String text) => '\u2066$text\u2069';

  @override
  String get shellHome => isolate(super.shellHome);

  @override
  String get shellOpenDocuments => isolate(super.shellOpenDocuments);

  @override
  String get shellOpenFile => isolate(super.shellOpenFile);

  @override
  String get shellCloseDocument => isolate(super.shellCloseDocument);

  @override
  String get shellUnsavedChanges => isolate(super.shellUnsavedChanges);

  @override
  String get shellOpening => isolate(super.shellOpening);

  @override
  String shellMoreDocuments(String count) =>
      isolate(super.shellMoreDocuments(count));

  @override
  String shellMoreDocumentsBadge(String count) =>
      isolate(super.shellMoreDocumentsBadge(count));

  @override
  String get shellSearch => isolate(super.shellSearch);

  @override
  String get shellSettings => isolate(super.shellSettings);

  @override
  String get shellModeLabel => isolate(super.shellModeLabel);

  @override
  String get shellModeView => isolate(super.shellModeView);

  @override
  String get shellModeEdit => isolate(super.shellModeEdit);

  @override
  String get shellModeComment => isolate(super.shellModeComment);

  @override
  String get shellModeSign => isolate(super.shellModeSign);

  @override
  String get shellModeOrganize => isolate(super.shellModeOrganize);

  @override
  String get shellModeConvert => isolate(super.shellModeConvert);

  @override
  String get shellModeProtect => isolate(super.shellModeProtect);

  @override
  String get shellModeTools => isolate(super.shellModeTools);

  @override
  String get shellToggleSidebar => isolate(super.shellToggleSidebar);

  @override
  String get shellTogglePanel => isolate(super.shellTogglePanel);

  @override
  String get shellAiAssistant => isolate(super.shellAiAssistant);

  @override
  String get shellSave => isolate(super.shellSave);

  @override
  String get shellNoChangesToSave => isolate(super.shellNoChangesToSave);

  @override
  String get shellViewTools => isolate(super.shellViewTools);

  @override
  String get shellToolSelect => isolate(super.shellToolSelect);

  @override
  String get shellToolHand => isolate(super.shellToolHand);

  @override
  String get shellToolMarqueeZoom => isolate(super.shellToolMarqueeZoom);

  @override
  String get shellZoomOut => isolate(super.shellZoomOut);

  @override
  String get shellZoomIn => isolate(super.shellZoomIn);

  @override
  String get shellZoom => isolate(super.shellZoom);

  @override
  String get shellFit => isolate(super.shellFit);

  @override
  String get shellFitWidth => isolate(super.shellFitWidth);

  @override
  String get shellFitPage => isolate(super.shellFitPage);

  @override
  String get shellActualSize => isolate(super.shellActualSize);

  @override
  String get shellPageLayout => isolate(super.shellPageLayout);

  @override
  String get shellLayoutSingle => isolate(super.shellLayoutSingle);

  @override
  String get shellLayoutContinuous => isolate(super.shellLayoutContinuous);

  @override
  String get shellLayoutTwoPage => isolate(super.shellLayoutTwoPage);

  @override
  String get shellLayoutBook => isolate(super.shellLayoutBook);

  @override
  String get shellToolSplitView => isolate(super.shellToolSplitView);

  @override
  String get shellToolReadAloud => isolate(super.shellToolReadAloud);

  @override
  String get shellToolPresent => isolate(super.shellToolPresent);

  @override
  String get shellDarkReadingMode => isolate(super.shellDarkReadingMode);

  @override
  String get shellEditTools => isolate(super.shellEditTools);

  @override
  String get shellToolEditText => isolate(super.shellToolEditText);

  @override
  String get shellToolAddText => isolate(super.shellToolAddText);

  @override
  String get shellToolAddImage => isolate(super.shellToolAddImage);

  @override
  String get shellToolLink => isolate(super.shellToolLink);

  @override
  String get shellToolFindReplace => isolate(super.shellToolFindReplace);

  @override
  String get shellToolPageMarks => isolate(super.shellToolPageMarks);

  @override
  String get shellUndo => isolate(super.shellUndo);

  @override
  String get shellRedo => isolate(super.shellRedo);

  @override
  String get shellEditHistory => isolate(super.shellEditHistory);

  @override
  String get shellMarkEditedText => isolate(super.shellMarkEditedText);

  @override
  String get shellReviewEdits => isolate(super.shellReviewEdits);

  @override
  String get shellCommentTools => isolate(super.shellCommentTools);

  @override
  String get shellAnnotationHighlight =>
      isolate(super.shellAnnotationHighlight);

  @override
  String get shellAnnotationUnderline =>
      isolate(super.shellAnnotationUnderline);

  @override
  String get shellAnnotationStrikethrough =>
      isolate(super.shellAnnotationStrikethrough);

  @override
  String get shellAnnotationNote => isolate(super.shellAnnotationNote);

  @override
  String get shellAnnotationText => isolate(super.shellAnnotationText);

  @override
  String get shellAnnotationCallout => isolate(super.shellAnnotationCallout);

  @override
  String get shellAnnotationDraw => isolate(super.shellAnnotationDraw);

  @override
  String get shellAnnotationShapes => isolate(super.shellAnnotationShapes);

  @override
  String get shellAnnotationStamp => isolate(super.shellAnnotationStamp);

  @override
  String get shellToolMeasure => isolate(super.shellToolMeasure);

  @override
  String get shellColor => isolate(super.shellColor);

  @override
  String get shellColorYellow => isolate(super.shellColorYellow);

  @override
  String get shellColorGreen => isolate(super.shellColorGreen);

  @override
  String get shellColorBlue => isolate(super.shellColorBlue);

  @override
  String get shellColorPink => isolate(super.shellColorPink);

  @override
  String get shellColorOrange => isolate(super.shellColorOrange);

  @override
  String get shellColorRed => isolate(super.shellColorRed);

  @override
  String get shellColorBlack => isolate(super.shellColorBlack);

  @override
  String get shellShowComments => isolate(super.shellShowComments);

  @override
  String get shellFillSignTools => isolate(super.shellFillSignTools);

  @override
  String get shellToolFillFields => isolate(super.shellToolFillFields);

  @override
  String get shellToolCheckmark => isolate(super.shellToolCheckmark);

  @override
  String get shellToolDate => isolate(super.shellToolDate);

  @override
  String get shellToolSign => isolate(super.shellToolSign);

  @override
  String get shellToolInitials => isolate(super.shellToolInitials);

  @override
  String get shellToolDigitalSignature =>
      isolate(super.shellToolDigitalSignature);

  @override
  String get shellToolEimza => isolate(super.shellToolEimza);

  @override
  String get shellToolPrepareForm => isolate(super.shellToolPrepareForm);

  @override
  String get shellOrganizeTools => isolate(super.shellOrganizeTools);

  @override
  String get shellToolInsert => isolate(super.shellToolInsert);

  @override
  String get shellToolRotateLeft => isolate(super.shellToolRotateLeft);

  @override
  String get shellToolRotateRight => isolate(super.shellToolRotateRight);

  @override
  String get shellToolDuplicate => isolate(super.shellToolDuplicate);

  @override
  String get shellToolExtract => isolate(super.shellToolExtract);

  @override
  String get shellToolReplace => isolate(super.shellToolReplace);

  @override
  String get shellToolDelete => isolate(super.shellToolDelete);

  @override
  String get shellToolSplit => isolate(super.shellToolSplit);

  @override
  String get shellToolCombineFiles => isolate(super.shellToolCombineFiles);

  @override
  String get shellToolCrop => isolate(super.shellToolCrop);

  @override
  String get shellToolPageLabels => isolate(super.shellToolPageLabels);

  @override
  String get shellOrganizeHint => isolate(super.shellOrganizeHint);

  @override
  String get shellConvertTools => isolate(super.shellConvertTools);

  @override
  String get shellConvertWord => isolate(super.shellConvertWord);

  @override
  String get shellConvertExcel => isolate(super.shellConvertExcel);

  @override
  String get shellConvertPowerPoint => isolate(super.shellConvertPowerPoint);

  @override
  String get shellConvertImage => isolate(super.shellConvertImage);

  @override
  String get shellConvertHtml => isolate(super.shellConvertHtml);

  @override
  String get shellConvertText => isolate(super.shellConvertText);

  @override
  String get shellConvertMarkdown => isolate(super.shellConvertMarkdown);

  @override
  String get shellToolCreatePdf => isolate(super.shellToolCreatePdf);

  @override
  String get shellToolScan => isolate(super.shellToolScan);

  @override
  String get shellToolRecognizeText => isolate(super.shellToolRecognizeText);

  @override
  String get shellProtectTools => isolate(super.shellProtectTools);

  @override
  String get shellToolRedact => isolate(super.shellToolRedact);

  @override
  String get shellToolFindRedact => isolate(super.shellToolFindRedact);

  @override
  String get shellToolPassword => isolate(super.shellToolPassword);

  @override
  String get shellToolRemoveHidden => isolate(super.shellToolRemoveHidden);

  @override
  String get shellToolSecurityReport => isolate(super.shellToolSecurityReport);

  @override
  String get shellApplyRedactions => isolate(super.shellApplyRedactions);

  @override
  String get shellToolCompress => isolate(super.shellToolCompress);

  @override
  String get shellToolCompare => isolate(super.shellToolCompare);

  @override
  String get shellToolAccessibility => isolate(super.shellToolAccessibility);

  @override
  String get shellToolPdfA => isolate(super.shellToolPdfA);

  @override
  String get shellToolBatch => isolate(super.shellToolBatch);

  @override
  String get shellToolPrint => isolate(super.shellToolPrint);

  @override
  String get shellToolVersionHistory => isolate(super.shellToolVersionHistory);

  @override
  String get fieldContextMenu => isolate(super.fieldContextMenu);

  @override
  String get fieldCut => isolate(super.fieldCut);

  @override
  String get fieldCopy => isolate(super.fieldCopy);

  @override
  String get fieldPaste => isolate(super.fieldPaste);

  @override
  String get fieldSelectAll => isolate(super.fieldSelectAll);

  @override
  String get shellResizeSidebar => isolate(super.shellResizeSidebar);

  @override
  String get shellResizePanel => isolate(super.shellResizePanel);

  @override
  String get shellSidebar => isolate(super.shellSidebar);

  @override
  String get shellSidebarPages => isolate(super.shellSidebarPages);

  @override
  String get shellSidebarOutline => isolate(super.shellSidebarOutline);

  @override
  String get shellSidebarAttachments => isolate(super.shellSidebarAttachments);

  @override
  String get shellSidebarLayers => isolate(super.shellSidebarLayers);

  @override
  String get shellSidebarSignatures => isolate(super.shellSidebarSignatures);

  @override
  String get shellSidebarSearch => isolate(super.shellSidebarSearch);

  @override
  String get shellPageBadgesLegend => isolate(super.shellPageBadgesLegend);

  @override
  String get shellAddBookmark => isolate(super.shellAddBookmark);

  @override
  String get shellMore => isolate(super.shellMore);

  @override
  String get shellMoreTools => isolate(super.shellMoreTools);

  @override
  String shellReviewEditsCount(String count) =>
      isolate(super.shellReviewEditsCount(count));

  @override
  String get shellWindowTooNarrow => isolate(super.shellWindowTooNarrow);

  @override
  String get shellAttachFile => isolate(super.shellAttachFile);

  @override
  String get shellPanelDocument => isolate(super.shellPanelDocument);

  @override
  String get shellCanvas => isolate(super.shellCanvas);

  @override
  String get shellPreviousPage => isolate(super.shellPreviousPage);

  @override
  String get shellNextPage => isolate(super.shellNextPage);

  @override
  String shellPageOf(String page, String count) =>
      isolate(super.shellPageOf(page, count));

  @override
  String shellSavedOnDevice(String time) =>
      isolate(super.shellSavedOnDevice(time));

  @override
  String get shellSaving => isolate(super.shellSaving);

  @override
  String get shellSaveError => isolate(super.shellSaveError);

  @override
  String get shellReadOnly => isolate(super.shellReadOnly);

  @override
  String get appName => isolate(super.appName);

  @override
  String get availableInFutureVersion =>
      isolate(super.availableInFutureVersion);

  @override
  String get windowMinimize => isolate(super.windowMinimize);

  @override
  String get windowMaximize => isolate(super.windowMaximize);

  @override
  String get windowRestore => isolate(super.windowRestore);

  @override
  String get windowClose => isolate(super.windowClose);

  @override
  String get languageAppLanguage => isolate(super.languageAppLanguage);

  @override
  String get languageSystem => isolate(super.languageSystem);

  @override
  String get languageNotTranslated => isolate(super.languageNotTranslated);

  @override
  String languageOptionNotTranslated(String language) =>
      isolate(super.languageOptionNotTranslated(language));

  @override
  String get languageNameEnglish => isolate(super.languageNameEnglish);

  @override
  String get languageNameTurkish => isolate(super.languageNameTurkish);

  @override
  String get languageNameArabic => isolate(super.languageNameArabic);

  @override
  String get onboardingLanguageTitle => isolate(super.onboardingLanguageTitle);

  @override
  String onboardingLanguageSubtitleSystem(String language) =>
      isolate(super.onboardingLanguageSubtitleSystem(language));

  @override
  String get onboardingLanguageSubtitle =>
      isolate(super.onboardingLanguageSubtitle);

  @override
  String get onboardingLanguageSearchPlaceholder =>
      isolate(super.onboardingLanguageSearchPlaceholder);

  @override
  String get onboardingLanguageSearchPlaceholderPhone =>
      isolate(super.onboardingLanguageSearchPlaceholderPhone);

  @override
  String get onboardingLanguageSearchLabel =>
      isolate(super.onboardingLanguageSearchLabel);

  @override
  String onboardingLanguageNoMatch(String query) =>
      isolate(super.onboardingLanguageNoMatch(query));

  @override
  String get onboardingLanguageNoMatchBody =>
      isolate(super.onboardingLanguageNoMatchBody);

  @override
  String get onboardingLanguageMissing =>
      isolate(super.onboardingLanguageMissing);

  @override
  String get onboardingLanguageHelpTranslate =>
      isolate(super.onboardingLanguageHelpTranslate);

  @override
  String get onboardingContinue => isolate(super.onboardingContinue);

  @override
  String onboardingStep(String step, String count) =>
      isolate(super.onboardingStep(step, count));

  @override
  String onboardingStepLabel(String step, String count) =>
      isolate(super.onboardingStepLabel(step, count));

  @override
  String get onboardingSkip => isolate(super.onboardingSkip);

  @override
  String get onboardingBack => isolate(super.onboardingBack);

  @override
  String get onboardingNext => isolate(super.onboardingNext);

  @override
  String get onboardingStartUsing => isolate(super.onboardingStartUsing);

  @override
  String get onboardingEditTitle => isolate(super.onboardingEditTitle);

  @override
  String get onboardingEditBody => isolate(super.onboardingEditBody);

  @override
  String get onboardingEditGlyphs => isolate(super.onboardingEditGlyphs);

  @override
  String get onboardingPrivacyTitle => isolate(super.onboardingPrivacyTitle);

  @override
  String get onboardingPrivacyBody => isolate(super.onboardingPrivacyBody);

  @override
  String get onboardingPrivacyFilesTitle =>
      isolate(super.onboardingPrivacyFilesTitle);

  @override
  String get onboardingPrivacyFilesBody =>
      isolate(super.onboardingPrivacyFilesBody);

  @override
  String get onboardingPrivacyOfflineTitle =>
      isolate(super.onboardingPrivacyOfflineTitle);

  @override
  String get onboardingPrivacyOfflineBody =>
      isolate(super.onboardingPrivacyOfflineBody);

  @override
  String get onboardingPrivacyAccountTitle =>
      isolate(super.onboardingPrivacyAccountTitle);

  @override
  String get onboardingPrivacyAccountBody =>
      isolate(super.onboardingPrivacyAccountBody);

  @override
  String get onboardingPrivacyTelemetryTitle =>
      isolate(super.onboardingPrivacyTelemetryTitle);

  @override
  String get onboardingPrivacyTelemetryBody =>
      isolate(super.onboardingPrivacyTelemetryBody);

  @override
  String get onboardingPrivacyUpdatesTitle =>
      isolate(super.onboardingPrivacyUpdatesTitle);

  @override
  String get onboardingPrivacyUpdatesBody =>
      isolate(super.onboardingPrivacyUpdatesBody);

  @override
  String get onboardingPrivacyPacksTitle =>
      isolate(super.onboardingPrivacyPacksTitle);

  @override
  String get onboardingPrivacyPacksBody =>
      isolate(super.onboardingPrivacyPacksBody);

  @override
  String get onboardingPrivacyAiTitle =>
      isolate(super.onboardingPrivacyAiTitle);

  @override
  String get onboardingPrivacyAiBody => isolate(super.onboardingPrivacyAiBody);

  @override
  String get onboardingPrivacyTimestampsTitle =>
      isolate(super.onboardingPrivacyTimestampsTitle);

  @override
  String get onboardingPrivacyTimestampsBody =>
      isolate(super.onboardingPrivacyTimestampsBody);

  @override
  String get onboardingPrivacySettingsLink =>
      isolate(super.onboardingPrivacySettingsLink);

  @override
  String get onboardingFreeTitle => isolate(super.onboardingFreeTitle);

  @override
  String get onboardingFreeBody => isolate(super.onboardingFreeBody);

  @override
  String get onboardingFreeLicence => isolate(super.onboardingFreeLicence);

  @override
  String get onboardingFreeSourceCode =>
      isolate(super.onboardingFreeSourceCode);

  @override
  String get onboardingFreeSupport => isolate(super.onboardingFreeSupport);

  @override
  String get onboardingFeatureEditing =>
      isolate(super.onboardingFeatureEditing);

  @override
  String get onboardingFeatureOcr => isolate(super.onboardingFeatureOcr);

  @override
  String get onboardingFeatureFillSign =>
      isolate(super.onboardingFeatureFillSign);

  @override
  String get onboardingFeatureSignatures =>
      isolate(super.onboardingFeatureSignatures);

  @override
  String get onboardingFeatureRedaction =>
      isolate(super.onboardingFeatureRedaction);

  @override
  String get onboardingFeatureConvert =>
      isolate(super.onboardingFeatureConvert);

  @override
  String get onboardingFeatureCompare =>
      isolate(super.onboardingFeatureCompare);

  @override
  String get onboardingFeatureBatch => isolate(super.onboardingFeatureBatch);

  @override
  String get onboardingFeatureAccessibility =>
      isolate(super.onboardingFeatureAccessibility);

  @override
  String onboardingFeatureLanguages(int count, String formatted) =>
      isolate(super.onboardingFeatureLanguages(count, formatted));

  @override
  String get onboardingFeatureIncluded =>
      isolate(super.onboardingFeatureIncluded);

  @override
  String get startOpenFile => isolate(super.startOpenFile);

  @override
  String get startOpenFileDescription =>
      isolate(super.startOpenFileDescription);

  @override
  String get startCreatePdf => isolate(super.startCreatePdf);

  @override
  String get startCreatePdfDescription =>
      isolate(super.startCreatePdfDescription);

  @override
  String get startCombineFiles => isolate(super.startCombineFiles);

  @override
  String get startCombineFilesDescription =>
      isolate(super.startCombineFilesDescription);

  @override
  String get startScanToPdf => isolate(super.startScanToPdf);

  @override
  String get startScanToPdfDescription =>
      isolate(super.startScanToPdfDescription);

  @override
  String get startQuickTools => isolate(super.startQuickTools);

  @override
  String get startToolCompress => isolate(super.startToolCompress);

  @override
  String get startToolConvert => isolate(super.startToolConvert);

  @override
  String get startToolSign => isolate(super.startToolSign);

  @override
  String get startToolOcr => isolate(super.startToolOcr);

  @override
  String get startToolProtect => isolate(super.startToolProtect);

  @override
  String get startToolCompare => isolate(super.startToolCompare);

  @override
  String get startDropTitle => isolate(super.startDropTitle);

  @override
  String get startDropSubtitle => isolate(super.startDropSubtitle);

  @override
  String get startDropFootnote => isolate(super.startDropFootnote);

  @override
  String get startOpenPdf => isolate(super.startOpenPdf);

  @override
  String get startNewBlankPdf => isolate(super.startNewBlankPdf);

  @override
  String get startEngineUnavailableTitle =>
      isolate(super.startEngineUnavailableTitle);

  @override
  String get startEngineUnavailableMessage =>
      isolate(super.startEngineUnavailableMessage);

  @override
  String get startCopyTechnicalDetails =>
      isolate(super.startCopyTechnicalDetails);

  @override
  String get settingsTitle => isolate(super.settingsTitle);

  @override
  String get settingsSearch => isolate(super.settingsSearch);

  @override
  String get settingsClose => isolate(super.settingsClose);

  @override
  String get settingsSaveFailedTitle => isolate(super.settingsSaveFailedTitle);

  @override
  String get settingsSaveFailedMessage =>
      isolate(super.settingsSaveFailedMessage);

  @override
  String get settingsSaveFailedDismiss =>
      isolate(super.settingsSaveFailedDismiss);

  @override
  String get settingsPaneGeneral => isolate(super.settingsPaneGeneral);

  @override
  String get settingsPaneLanguage => isolate(super.settingsPaneLanguage);

  @override
  String get settingsPaneEditing => isolate(super.settingsPaneEditing);

  @override
  String get settingsPaneFonts => isolate(super.settingsPaneFonts);

  @override
  String get settingsPaneSignatures => isolate(super.settingsPaneSignatures);

  @override
  String get settingsPaneOcr => isolate(super.settingsPaneOcr);

  @override
  String get settingsPaneAi => isolate(super.settingsPaneAi);

  @override
  String get settingsPhoneGroupDocuments =>
      isolate(super.settingsPhoneGroupDocuments);

  @override
  String get settingsPhoneGroupApp => isolate(super.settingsPhoneGroupApp);

  @override
  String get settingsPhoneGroupRegion =>
      isolate(super.settingsPhoneGroupRegion);

  @override
  String get settingsPhonePrivacyValue =>
      isolate(super.settingsPhonePrivacyValue);

  @override
  String get settingsPhoneAbout => isolate(super.settingsPhoneAbout);

  @override
  String get settingsPanePrivacy => isolate(super.settingsPanePrivacy);

  @override
  String get settingsPaneUpdates => isolate(super.settingsPaneUpdates);

  @override
  String get settingsPaneShortcuts => isolate(super.settingsPaneShortcuts);

  @override
  String get settingsPaneAdvanced => isolate(super.settingsPaneAdvanced);

  @override
  String get settingsTheme => isolate(super.settingsTheme);

  @override
  String get settingsThemeSystem => isolate(super.settingsThemeSystem);

  @override
  String get settingsThemeLight => isolate(super.settingsThemeLight);

  @override
  String get settingsThemeDark => isolate(super.settingsThemeDark);

  @override
  String get settingsPageTheme => isolate(super.settingsPageTheme);

  @override
  String get settingsPagePaper => isolate(super.settingsPagePaper);

  @override
  String get settingsPagePaperDescription =>
      isolate(super.settingsPagePaperDescription);

  @override
  String get settingsPageDimmed => isolate(super.settingsPageDimmed);

  @override
  String get settingsPageDimmedDescription =>
      isolate(super.settingsPageDimmedDescription);

  @override
  String get settingsPageDark => isolate(super.settingsPageDark);

  @override
  String get settingsPageDarkDescription =>
      isolate(super.settingsPageDarkDescription);

  @override
  String get settingsPageLayout => isolate(super.settingsPageLayout);

  @override
  String get settingsPageLayoutScroll =>
      isolate(super.settingsPageLayoutScroll);

  @override
  String get settingsPageLayoutSingle =>
      isolate(super.settingsPageLayoutSingle);

  @override
  String get settingsPageLayoutSpread =>
      isolate(super.settingsPageLayoutSpread);

  @override
  String get settingsZoom => isolate(super.settingsZoom);

  @override
  String get settingsZoomFitWidth => isolate(super.settingsZoomFitWidth);

  @override
  String get settingsZoomFitPage => isolate(super.settingsZoomFitPage);

  @override
  String get settingsReopen => isolate(super.settingsReopen);

  @override
  String get settingsDefaultApp => isolate(super.settingsDefaultApp);

  @override
  String get settingsDefaultAppWindows =>
      isolate(super.settingsDefaultAppWindows);

  @override
  String get settingsMakeDefault => isolate(super.settingsMakeDefault);

  @override
  String get settingsAppLanguageHint => isolate(super.settingsAppLanguageHint);

  @override
  String get settingsDocumentLanguages =>
      isolate(super.settingsDocumentLanguages);

  @override
  String get settingsDocumentLanguagesHint =>
      isolate(super.settingsDocumentLanguagesHint);

  @override
  String get settingsAddDocumentLanguage =>
      isolate(super.settingsAddDocumentLanguage);

  @override
  String get settingsPrivacyStatement =>
      isolate(super.settingsPrivacyStatement);

  @override
  String get settingsPrivacyStatementBody =>
      isolate(super.settingsPrivacyStatementBody);

  @override
  String get settingsNetUpdates => isolate(super.settingsNetUpdates);

  @override
  String get settingsNetUpdatesDescription =>
      isolate(super.settingsNetUpdatesDescription);

  @override
  String get settingsNetSignatureChecks =>
      isolate(super.settingsNetSignatureChecks);

  @override
  String get settingsNetSignatureChecksDescription =>
      isolate(super.settingsNetSignatureChecksDescription);

  @override
  String get settingsNetTimestamps => isolate(super.settingsNetTimestamps);

  @override
  String get settingsNetTimestampsDescription =>
      isolate(super.settingsNetTimestampsDescription);

  @override
  String get settingsNetDownloads => isolate(super.settingsNetDownloads);

  @override
  String get settingsNetDownloadsDescription =>
      isolate(super.settingsNetDownloadsDescription);

  @override
  String get settingsNetAiProvider => isolate(super.settingsNetAiProvider);

  @override
  String get settingsNetAiProviderDescription =>
      isolate(super.settingsNetAiProviderDescription);

  @override
  String get settingsNetworkActivity => isolate(super.settingsNetworkActivity);

  @override
  String get regionFormats => isolate(super.regionFormats);

  @override
  String get regionPaperSize => isolate(super.regionPaperSize);

  @override
  String get regionPaperA4 => isolate(super.regionPaperA4);

  @override
  String get regionPaperLetter => isolate(super.regionPaperLetter);

  @override
  String get regionUnits => isolate(super.regionUnits);

  @override
  String get regionFirstDay => isolate(super.regionFirstDay);

  @override
  String get regionMonday => isolate(super.regionMonday);

  @override
  String get regionSunday => isolate(super.regionSunday);

  @override
  String get regionSaturday => isolate(super.regionSaturday);

  @override
  String get regionFriday => isolate(super.regionFriday);

  @override
  String get regionExamples => isolate(super.regionExamples);

  @override
  String get regionExampleDate => isolate(super.regionExampleDate);

  @override
  String get regionExampleTime => isolate(super.regionExampleTime);

  @override
  String get regionExampleNumber => isolate(super.regionExampleNumber);

  @override
  String get regionExampleFontSize => isolate(super.regionExampleFontSize);

  @override
  String viewerPageFailed(String page) => isolate(super.viewerPageFailed(page));

  @override
  String get viewerPageFailedReason => isolate(super.viewerPageFailedReason);

  @override
  String get viewerTryAgain => isolate(super.viewerTryAgain);

  @override
  String viewerMarqueeZoom(String zoom) =>
      isolate(super.viewerMarqueeZoom(zoom));

  @override
  String editHoverTip(String block) => isolate(super.editHoverTip(block));

  @override
  String get editNotEditableTitle => isolate(super.editNotEditableTitle);

  @override
  String get editTipImageOnly => isolate(super.editTipImageOnly);

  @override
  String get editBodyImageOnly => isolate(super.editBodyImageOnly);

  @override
  String get editTipOutlinedText => isolate(super.editTipOutlinedText);

  @override
  String get editBodyOutlinedText => isolate(super.editBodyOutlinedText);

  @override
  String get editTipUnknownText => isolate(super.editTipUnknownText);

  @override
  String get editBodyUnknownText => isolate(super.editBodyUnknownText);

  @override
  String get editTipInvisibleText => isolate(super.editTipInvisibleText);

  @override
  String get editBodyInvisibleText => isolate(super.editBodyInvisibleText);

  @override
  String get editTipRestricted => isolate(super.editTipRestricted);

  @override
  String get editBodyRestricted => isolate(super.editBodyRestricted);

  @override
  String get editTipReadOnly => isolate(super.editTipReadOnly);

  @override
  String get editBodyReadOnly => isolate(super.editBodyReadOnly);

  @override
  String get editTipDamaged => isolate(super.editTipDamaged);

  @override
  String get editBodyDamaged => isolate(super.editBodyDamaged);

  @override
  String get editTipSignature => isolate(super.editTipSignature);

  @override
  String get editBodySignature => isolate(super.editBodySignature);

  @override
  String get editTipAnnotation => isolate(super.editTipAnnotation);

  @override
  String get editBodyAnnotation => isolate(super.editBodyAnnotation);

  @override
  String get editTipTooComplex => isolate(super.editTipTooComplex);

  @override
  String get editBodyLimits => isolate(super.editBodyLimits);

  @override
  String get editBodySplit => isolate(super.editBodySplit);

  @override
  String get editBodySkewed => isolate(super.editBodySkewed);

  @override
  String get viewerTextMenu => isolate(super.viewerTextMenu);

  @override
  String get viewerPageNumber => isolate(super.viewerPageNumber);

  @override
  String sidebarPage(String page) => isolate(super.sidebarPage(page));

  @override
  String get sidebarNoBookmarks => isolate(super.sidebarNoBookmarks);

  @override
  String get sidebarNoBookmarksBody => isolate(super.sidebarNoBookmarksBody);

  @override
  String get sidebarNoAttachments => isolate(super.sidebarNoAttachments);

  @override
  String get sidebarNoAttachmentsBody =>
      isolate(super.sidebarNoAttachmentsBody);

  @override
  String get sidebarNoLayers => isolate(super.sidebarNoLayers);

  @override
  String get sidebarNoLayersBody => isolate(super.sidebarNoLayersBody);

  @override
  String get sidebarNoSignatures => isolate(super.sidebarNoSignatures);

  @override
  String get sidebarNoSignaturesBody => isolate(super.sidebarNoSignaturesBody);

  @override
  String get sidebarAttachmentsNote => isolate(super.sidebarAttachmentsNote);

  @override
  String get sidebarSaveAttachment => isolate(super.sidebarSaveAttachment);

  @override
  String get sidebarLayersNote => isolate(super.sidebarLayersNote);

  @override
  String get sidebarHideLayer => isolate(super.sidebarHideLayer);

  @override
  String get sidebarShowLayer => isolate(super.sidebarShowLayer);

  @override
  String get sidebarLayerLocked => isolate(super.sidebarLayerLocked);

  @override
  String get sidebarSignatureCheckingLater =>
      isolate(super.sidebarSignatureCheckingLater);

  @override
  String get sidebarEmptySignatureField =>
      isolate(super.sidebarEmptySignatureField);

  @override
  String get findRegion => isolate(super.findRegion);

  @override
  String get findField => isolate(super.findField);

  @override
  String get findReplaceWith => isolate(super.findReplaceWith);

  @override
  String get findMatchCase => isolate(super.findMatchCase);

  @override
  String get findWholeWords => isolate(super.findWholeWords);

  @override
  String get findRegex => isolate(super.findRegex);

  @override
  String get findShowReplace => isolate(super.findShowReplace);

  @override
  String get findHideReplace => isolate(super.findHideReplace);

  @override
  String get findPrevious => isolate(super.findPrevious);

  @override
  String get findNext => isolate(super.findNext);

  @override
  String get findReplaceAll => isolate(super.findReplaceAll);

  @override
  String get findNoResults => isolate(super.findNoResults);

  @override
  String get findOptions => isolate(super.findOptions);

  @override
  String get findMatch => isolate(super.findMatch);

  @override
  String get findIgnoreAccents => isolate(super.findIgnoreAccents);

  @override
  String get findIgnoreAccentsBody => isolate(super.findIgnoreAccentsBody);

  @override
  String get findLookIn => isolate(super.findLookIn);

  @override
  String get findPageText => isolate(super.findPageText);

  @override
  String get findComments => isolate(super.findComments);

  @override
  String get findFormFields => isolate(super.findFormFields);

  @override
  String get findBookmarks => isolate(super.findBookmarks);

  @override
  String get findSearchingBody => isolate(super.findSearchingBody);

  @override
  String get findCancel => isolate(super.findCancel);

  @override
  String get findNoneAction => isolate(super.findNoneAction);

  @override
  String findCount(String current, String total) =>
      isolate(super.findCount(current, total));

  @override
  String get statusSearching => isolate(super.statusSearching);

  @override
  String findSearching(String page, String pages) =>
      isolate(super.findSearching(page, pages));

  @override
  String findNoneTitle(String query) => isolate(super.findNoneTitle(query));

  @override
  String findNoneBody(int count, String pages) =>
      isolate(super.findNoneBody(count, pages));

  @override
  String findNoneBodyExact(int count, String pages) =>
      isolate(super.findNoneBodyExact(count, pages));

  @override
  String get findNotSearchedFields => isolate(super.findNotSearchedFields);

  @override
  String get findNotSearchedBoth => isolate(super.findNotSearchedBoth);

  @override
  String get sidebarSearchField => isolate(super.sidebarSearchField);

  @override
  String sidebarSearchBookmark(String title) =>
      isolate(super.sidebarSearchBookmark(title));

  @override
  String get sidebarSearchNoTextTitle =>
      isolate(super.sidebarSearchNoTextTitle);

  @override
  String get sidebarSearchNoTextBody => isolate(super.sidebarSearchNoTextBody);

  @override
  String sidebarSearchSummary(
    int matches,
    String matchesText,
    int pages,
    String pagesText,
  ) => isolate(
    super.sidebarSearchSummary(matches, matchesText, pages, pagesText),
  );

  @override
  String get openPdfFilter => isolate(super.openPdfFilter);

  @override
  String openFailedTitle(String name) => isolate(super.openFailedTitle(name));

  @override
  String get openFailedDismiss => isolate(super.openFailedDismiss);

  @override
  String get shellSavedOnDeviceUndated =>
      isolate(super.shellSavedOnDeviceUndated);

  @override
  String get shellMoreDocumentsMenu => isolate(super.shellMoreDocumentsMenu);

  @override
  String shellMoreDocumentsHeading(int count, String countText) =>
      isolate(super.shellMoreDocumentsHeading(count, countText));

  @override
  String shellMoreDocumentsUnsaved(String name) =>
      isolate(super.shellMoreDocumentsUnsaved(name));

  @override
  String get shellShowAllDocuments => isolate(super.shellShowAllDocuments);

  @override
  String get shellCloseOtherDocuments =>
      isolate(super.shellCloseOtherDocuments);

  @override
  String get dropOverlayTitle => isolate(super.dropOverlayTitle);

  @override
  String get dropOverlayHint => isolate(super.dropOverlayHint);

  @override
  String get dropOverlayTabs => isolate(super.dropOverlayTabs);

  @override
  String get dropOverlayTabsDescription =>
      isolate(super.dropOverlayTabsDescription);

  @override
  String get dropOverlayCombine => isolate(super.dropOverlayCombine);

  @override
  String get startDropStripTitle => isolate(super.startDropStripTitle);

  @override
  String get startDropStripSubtitle => isolate(super.startDropStripSubtitle);

  @override
  String get startPhoneSearch => isolate(super.startPhoneSearch);

  @override
  String get startPhoneToolCombine => isolate(super.startPhoneToolCombine);

  @override
  String get startPhoneToolOcr => isolate(super.startPhoneToolOcr);

  @override
  String get startPhoneEmptyTitle => isolate(super.startPhoneEmptyTitle);

  @override
  String get startPhoneEmptySubtitle => isolate(super.startPhoneEmptySubtitle);

  @override
  String get startPhoneOpen => isolate(super.startPhoneOpen);

  @override
  String get startPhoneScan => isolate(super.startPhoneScan);

  @override
  String get startPhoneSeeAll => isolate(super.startPhoneSeeAll);

  @override
  String get startPhoneOpenFrom => isolate(super.startPhoneOpenFrom);

  @override
  String get startPhoneSourceDownloads =>
      isolate(super.startPhoneSourceDownloads);

  @override
  String get startPhoneSourceGoogleDrive =>
      isolate(super.startPhoneSourceGoogleDrive);

  @override
  String get startPhoneSourceOneDrive =>
      isolate(super.startPhoneSourceOneDrive);

  @override
  String get startPhoneRecent => isolate(super.startPhoneRecent);

  @override
  String get startPinned => isolate(super.startPinned);

  @override
  String get startPin => isolate(super.startPin);

  @override
  String get startUnpin => isolate(super.startUnpin);

  @override
  String get startRecent => isolate(super.startRecent);

  @override
  String get startSearchRecent => isolate(super.startSearchRecent);

  @override
  String get startSort => isolate(super.startSort);

  @override
  String get startSortOpened => isolate(super.startSortOpened);

  @override
  String get startSortName => isolate(super.startSortName);

  @override
  String get startSortLocation => isolate(super.startSortLocation);

  @override
  String get startView => isolate(super.startView);

  @override
  String get startViewGrid => isolate(super.startViewGrid);

  @override
  String get startViewList => isolate(super.startViewList);

  @override
  String get startColumnPages => isolate(super.startColumnPages);

  @override
  String get startColumnOpened => isolate(super.startColumnOpened);

  @override
  String get startRecentFooter => isolate(super.startRecentFooter);

  @override
  String get startClearList => isolate(super.startClearList);

  @override
  String startNoRecentMatch(String query) =>
      isolate(super.startNoRecentMatch(query));

  @override
  String startPages(int count, String pages) =>
      isolate(super.startPages(count, pages));

  @override
  String startOpenedToday(String time) => isolate(super.startOpenedToday(time));

  @override
  String startOpenedYesterday(String time) =>
      isolate(super.startOpenedYesterday(time));

  @override
  String get startBadgeEdited => isolate(super.startBadgeEdited);

  @override
  String get startBadgeSigned => isolate(super.startBadgeSigned);

  @override
  String get startBadgeForm => isolate(super.startBadgeForm);

  @override
  String get startBadgeScanned => isolate(super.startBadgeScanned);

  @override
  String startMissingTitle(String name) =>
      isolate(super.startMissingTitle(name));

  @override
  String startMissingDescription(String folder) =>
      isolate(super.startMissingDescription(folder));

  @override
  String get startMissingRemove => isolate(super.startMissingRemove);

  @override
  String get startMissingLocate => isolate(super.startMissingLocate);

  @override
  String get startMissingClose => isolate(super.startMissingClose);

  @override
  String get selectSheetSearch => isolate(super.selectSheetSearch);

  @override
  String get selectSheetNoMatch => isolate(super.selectSheetNoMatch);

  @override
  String get selectSheetClose => isolate(super.selectSheetClose);

  @override
  String get errorInternal => isolate(super.errorInternal);

  @override
  String get errorFileNotFound => isolate(super.errorFileNotFound);

  @override
  String get errorFilePermissionDenied =>
      isolate(super.errorFilePermissionDenied);

  @override
  String get errorFileRead => isolate(super.errorFileRead);

  @override
  String errorNotPdf(String name) => isolate(super.errorNotPdf(name));

  @override
  String get errorPasswordRequired => isolate(super.errorPasswordRequired);

  @override
  String get errorWrongPassword => isolate(super.errorWrongPassword);

  @override
  String get errorDamaged => isolate(super.errorDamaged);

  @override
  String get errorDamagedTruncated => isolate(super.errorDamagedTruncated);

  @override
  String get errorDamagedEmpty => isolate(super.errorDamagedEmpty);

  @override
  String get errorUnsupported => isolate(super.errorUnsupported);

  @override
  String get errorTooComplex => isolate(super.errorTooComplex);

  @override
  String get errorOutOfMemory => isolate(super.errorOutOfMemory);

  @override
  String openClosedTitle(String name) => isolate(super.openClosedTitle(name));

  @override
  String get openTryAgain => isolate(super.openTryAgain);

  @override
  String get openNotPdfTitle => isolate(super.openNotPdfTitle);

  @override
  String get openAnotherFile => isolate(super.openAnotherFile);

  @override
  String get openShowInFinder => isolate(super.openShowInFinder);

  @override
  String get openShowInExplorer => isolate(super.openShowInExplorer);

  @override
  String get openShowInFolder => isolate(super.openShowInFolder);

  @override
  String get openConvertToPdf => isolate(super.openConvertToPdf);

  @override
  String unlockDescription(String name) =>
      isolate(super.unlockDescription(name));

  @override
  String get unlockPassword => isolate(super.unlockPassword);

  @override
  String get unlockShowPassword => isolate(super.unlockShowPassword);

  @override
  String get unlockCancel => isolate(super.unlockCancel);

  @override
  String get unlockOpen => isolate(super.unlockOpen);

  @override
  String get restrictedTitle => isolate(super.restrictedTitle);

  @override
  String get restrictedBody => isolate(super.restrictedBody);

  @override
  String get restrictedBodyOther => isolate(super.restrictedBodyOther);

  @override
  String get restrictedUnlock => isolate(super.restrictedUnlock);

  @override
  String get ownerUnlockTitle => isolate(super.ownerUnlockTitle);

  @override
  String ownerUnlockDescription(String name) =>
      isolate(super.ownerUnlockDescription(name));

  @override
  String get ownerUnlockPassword => isolate(super.ownerUnlockPassword);

  @override
  String get ownerUnlockAction => isolate(super.ownerUnlockAction);

  @override
  String scriptsTitle(int count, String countText) =>
      isolate(super.scriptsTitle(count, countText));

  @override
  String get scriptsBody => isolate(super.scriptsBody);

  @override
  String get scriptsDismiss => isolate(super.scriptsDismiss);

  @override
  String get repairedTitle => isolate(super.repairedTitle);

  @override
  String repairedBody(int count, String countText) =>
      isolate(super.repairedBody(count, countText));

  @override
  String get repairedDetails => isolate(super.repairedDetails);

  @override
  String get repairedSave => isolate(super.repairedSave);

  @override
  String get repairDetailsTitle => isolate(super.repairDetailsTitle);

  @override
  String get repairCopyDetails => isolate(super.repairCopyDetails);

  @override
  String get repairXrefTitle => isolate(super.repairXrefTitle);

  @override
  String repairXrefBody(int count, String countText) =>
      isolate(super.repairXrefBody(count, countText));

  @override
  String repairPagesPresent(int count, String countText) =>
      isolate(super.repairPagesPresent(count, countText));

  @override
  String get repairTrailerTitle => isolate(super.repairTrailerTitle);

  @override
  String get repairTrailerBody => isolate(super.repairTrailerBody);

  @override
  String repairStreamsTitle(int count, String countText) =>
      isolate(super.repairStreamsTitle(count, countText));

  @override
  String get repairStreamsBody => isolate(super.repairStreamsBody);

  @override
  String repairUnreadableTitle(int count, String countText) =>
      isolate(super.repairUnreadableTitle(count, countText));

  @override
  String get repairUnreadableBody => isolate(super.repairUnreadableBody);

  @override
  String get xfaTitle => isolate(super.xfaTitle);

  @override
  String get xfaBody => isolate(super.xfaBody);

  @override
  String disagreeTitle(String name) => isolate(super.disagreeTitle(name));

  @override
  String get disagreeBody => isolate(super.disagreeBody);

  @override
  String get propertiesFile => isolate(super.propertiesFile);

  @override
  String get propertiesFonts => isolate(super.propertiesFonts);

  @override
  String get propertiesSecurity => isolate(super.propertiesSecurity);

  @override
  String get propertiesPages => isolate(super.propertiesPages);

  @override
  String get propertiesPageSize => isolate(super.propertiesPageSize);

  @override
  String get propertiesFileSize => isolate(super.propertiesFileSize);

  @override
  String get propertiesVersion => isolate(super.propertiesVersion);

  @override
  String propertiesVersionAcrobat(String version, String acrobat) =>
      isolate(super.propertiesVersionAcrobat(version, acrobat));

  @override
  String get propertiesLocation => isolate(super.propertiesLocation);

  @override
  String get propertiesCreated => isolate(super.propertiesCreated);

  @override
  String get propertiesModified => isolate(super.propertiesModified);

  @override
  String get propertiesTitle => isolate(super.propertiesTitle);

  @override
  String get propertiesAuthor => isolate(super.propertiesAuthor);

  @override
  String get propertiesSubject => isolate(super.propertiesSubject);

  @override
  String get propertiesKeywords => isolate(super.propertiesKeywords);

  @override
  String get propertiesTagged => isolate(super.propertiesTagged);

  @override
  String get propertiesFastWebView => isolate(super.propertiesFastWebView);

  @override
  String get propertiesMadeWith => isolate(super.propertiesMadeWith);

  @override
  String get propertiesYes => isolate(super.propertiesYes);

  @override
  String get propertiesNo => isolate(super.propertiesNo);

  @override
  String get propertiesNone => isolate(super.propertiesNone);

  @override
  String get propertiesNoPassword => isolate(super.propertiesNoPassword);

  @override
  String get propertiesOwnerPassword => isolate(super.propertiesOwnerPassword);

  @override
  String propertiesSignatures(int count, String countText) =>
      isolate(super.propertiesSignatures(count, countText));

  @override
  String propertiesSignatureOnPage(String page) =>
      isolate(super.propertiesSignatureOnPage(page));

  @override
  String get propertiesEmbedded => isolate(super.propertiesEmbedded);

  @override
  String get propertiesPartial => isolate(super.propertiesPartial);

  @override
  String get propertiesPartialNote => isolate(super.propertiesPartialNote);

  @override
  String propertiesPartialMissing(String letters) =>
      isolate(super.propertiesPartialMissing(letters));

  @override
  String get propertiesSubset => isolate(super.propertiesSubset);

  @override
  String get propertiesSubsetNote => isolate(super.propertiesSubsetNote);

  @override
  String propertiesSubsetMissing(String letters) =>
      isolate(super.propertiesSubsetMissing(letters));

  @override
  String propertiesShownInstead(String font) =>
      isolate(super.propertiesShownInstead(font));

  @override
  String get propertiesNotEmbedded => isolate(super.propertiesNotEmbedded);

  @override
  String get propertiesFontType1 => isolate(super.propertiesFontType1);

  @override
  String get propertiesFontMultipleMaster =>
      isolate(super.propertiesFontMultipleMaster);

  @override
  String get propertiesFontTrueType => isolate(super.propertiesFontTrueType);

  @override
  String get propertiesFontType0 => isolate(super.propertiesFontType0);

  @override
  String get propertiesFontType3 => isolate(super.propertiesFontType3);

  @override
  String get propertiesFontOther => isolate(super.propertiesFontOther);

  @override
  String get propertiesFontColumn => isolate(super.propertiesFontColumn);

  @override
  String get propertiesTypeColumn => isolate(super.propertiesTypeColumn);

  @override
  String get propertiesStatusColumn => isolate(super.propertiesStatusColumn);

  @override
  String propertiesDialogTitle(String name) =>
      isolate(super.propertiesDialogTitle(name));

  @override
  String get propertiesSection => isolate(super.propertiesSection);

  @override
  String get propertiesSummary => isolate(super.propertiesSummary);

  @override
  String get propertiesAdvanced => isolate(super.propertiesAdvanced);

  @override
  String get propertiesDone => isolate(super.propertiesDone);

  @override
  String get propertiesClose => isolate(super.propertiesClose);

  @override
  String get propertiesEncryption => isolate(super.propertiesEncryption);

  @override
  String propertiesRc4(String bits) => isolate(super.propertiesRc4(bits));

  @override
  String get propertiesAes128 => isolate(super.propertiesAes128);

  @override
  String get propertiesAes256 => isolate(super.propertiesAes256);

  @override
  String get propertiesOwnerPasswordSuffix =>
      isolate(super.propertiesOwnerPasswordSuffix);

  @override
  String get propertiesOpenPassword => isolate(super.propertiesOpenPassword);

  @override
  String get propertiesRequired => isolate(super.propertiesRequired);

  @override
  String get propertiesPermissions => isolate(super.propertiesPermissions);

  @override
  String get propertiesPrinting => isolate(super.propertiesPrinting);

  @override
  String get propertiesChanging => isolate(super.propertiesChanging);

  @override
  String get propertiesCommenting => isolate(super.propertiesCommenting);

  @override
  String get propertiesFilling => isolate(super.propertiesFilling);

  @override
  String get propertiesSigning => isolate(super.propertiesSigning);

  @override
  String get propertiesCopying => isolate(super.propertiesCopying);

  @override
  String get propertiesScreenReaders => isolate(super.propertiesScreenReaders);

  @override
  String get propertiesAssembling => isolate(super.propertiesAssembling);

  @override
  String get propertiesAllowed => isolate(super.propertiesAllowed);

  @override
  String get propertiesAllowedHighQuality =>
      isolate(super.propertiesAllowedHighQuality);

  @override
  String get propertiesNotAllowed => isolate(super.propertiesNotAllowed);

  @override
  String get propertiesLanguage => isolate(super.propertiesLanguage);

  @override
  String get propertiesScripts => isolate(super.propertiesScripts);

  @override
  String propertiesScriptsValue(int count, String countText) =>
      isolate(super.propertiesScriptsValue(count, countText));

  @override
  String openingTitle(String name) => isolate(super.openingTitle(name));

  @override
  String get openingCancel => isolate(super.openingCancel);

  @override
  String get defaultAppTitle => isolate(super.defaultAppTitle);

  @override
  String get defaultAppDescription => isolate(super.defaultAppDescription);

  @override
  String get defaultAppNow => isolate(super.defaultAppNow);

  @override
  String get defaultAppNotNow => isolate(super.defaultAppNotNow);

  @override
  String get defaultAppUse => isolate(super.defaultAppUse);

  @override
  String get defaultAppDontAsk => isolate(super.defaultAppDontAsk);

  @override
  String settingsDefaultAppOther(String app) =>
      isolate(super.settingsDefaultAppOther(app));

  @override
  String get settingsDefaultAppFerman =>
      isolate(super.settingsDefaultAppFerman);

  @override
  String attachmentNotSaved(String name) =>
      isolate(super.attachmentNotSaved(name));

  @override
  String get attachmentWriteFailed => isolate(super.attachmentWriteFailed);

  @override
  String editStepText(String page) => isolate(super.editStepText(page));

  @override
  String get editHistoryClose => isolate(super.editHistoryClose);

  @override
  String get editHistorySteps => isolate(super.editHistorySteps);

  @override
  String editHistoryOpened(String name) =>
      isolate(super.editHistoryOpened(name));

  @override
  String get editHistoryNote => isolate(super.editHistoryNote);

  @override
  String get editNothingToUndo => isolate(super.editNothingToUndo);

  @override
  String get editNothingToRedo => isolate(super.editNothingToRedo);

  @override
  String get editOverflowTitle => isolate(super.editOverflowTitle);

  @override
  String editOverflowBody(int count, String n) =>
      isolate(super.editOverflowBody(count, n));

  @override
  String editOverflowExtend(int count, String n) =>
      isolate(super.editOverflowExtend(count, n));

  @override
  String editOverflowTighten(String percent) =>
      isolate(super.editOverflowTighten(percent));

  @override
  String get editOverflowKeep => isolate(super.editOverflowKeep);

  @override
  String editOverflowExtendLabelBelow(String label) =>
      isolate(super.editOverflowExtendLabelBelow(label));

  @override
  String editOverflowExtendBelow(String text) =>
      isolate(super.editOverflowExtendBelow(text));

  @override
  String get editOverflowExtendPageEdge =>
      isolate(super.editOverflowExtendPageEdge);

  @override
  String editOverflowTightenShort(int count, String n) =>
      isolate(super.editOverflowTightenShort(count, n));

  @override
  String editOverflowHidden(int count, String n) =>
      isolate(super.editOverflowHidden(count, n));

  @override
  String get editTotalsTitle => isolate(super.editTotalsTitle);

  @override
  String get editTotalsBody => isolate(super.editTotalsBody);

  @override
  String editTotalsReview(int count, String n) =>
      isolate(super.editTotalsReview(count, n));

  @override
  String get editBadgeEdited => isolate(super.editBadgeEdited);

  @override
  String get editGlyphTitle => isolate(super.editGlyphTitle);

  @override
  String editGlyphBody(String chars) => isolate(super.editGlyphBody(chars));

  @override
  String editGlyphBodyMany(String chars) =>
      isolate(super.editGlyphBodyMany(chars));

  @override
  String editGlyphMarkedBody(String chars) =>
      isolate(super.editGlyphMarkedBody(chars));

  @override
  String get editGlyphChoose => isolate(super.editGlyphChoose);

  @override
  String get editGlyphKeep => isolate(super.editGlyphKeep);

  @override
  String get editGlyphNoneTitle => isolate(super.editGlyphNoneTitle);

  @override
  String editGlyphNoneBody(String chars) =>
      isolate(super.editGlyphNoneBody(chars));

  @override
  String get editGlyphLicenceTitle => isolate(super.editGlyphLicenceTitle);

  @override
  String editGlyphLicenceBody(String font, String chars) =>
      isolate(super.editGlyphLicenceBody(font, chars));

  @override
  String editGlyphLicenceBodyRestricted(String font, String chars) =>
      isolate(super.editGlyphLicenceBodyRestricted(font, chars));

  @override
  String editGlyphOwnFontBody(String font, String chars) =>
      isolate(super.editGlyphOwnFontBody(font, chars));

  @override
  String get editGlyphAddedTitle => isolate(super.editGlyphAddedTitle);

  @override
  String editGlyphAddedBody(String chars, String font) =>
      isolate(super.editGlyphAddedBody(chars, font));

  @override
  String get fontPickerTitle => isolate(super.fontPickerTitle);

  @override
  String get fontPickerClose => isolate(super.fontPickerClose);

  @override
  String get fontPickerScope => isolate(super.fontPickerScope);

  @override
  String get fontPickerScopeMissing => isolate(super.fontPickerScopeMissing);

  @override
  String get fontPickerScopeBlock => isolate(super.fontPickerScopeBlock);

  @override
  String get fontPickerSearch => isolate(super.fontPickerSearch);

  @override
  String get fontPickerEmbedded => isolate(super.fontPickerEmbedded);

  @override
  String get fontPickerInstalled => isolate(super.fontPickerInstalled);

  @override
  String get fontPickerBundled => isolate(super.fontPickerBundled);

  @override
  String get fontPickerClosest => isolate(super.fontPickerClosest);

  @override
  String fontPickerHas(String chars) => isolate(super.fontPickerHas(chars));

  @override
  String fontPickerHasNone(String chars) =>
      isolate(super.fontPickerHasNone(chars));

  @override
  String fontPickerHasSome(String covered, String needed) =>
      isolate(super.fontPickerHasSome(covered, needed));

  @override
  String get fontPickerNotEmbeddable => isolate(super.fontPickerNotEmbeddable);

  @override
  String fontPickerNoMatch(String query) =>
      isolate(super.fontPickerNoMatch(query));

  @override
  String get fontPickerCancel => isolate(super.fontPickerCancel);

  @override
  String fontPickerUse(String font) => isolate(super.fontPickerUse(font));

  @override
  String get editFontSubstituted => isolate(super.editFontSubstituted);

  @override
  String editFontSubstitutedBody(String font, String chars) =>
      isolate(super.editFontSubstitutedBody(font, chars));

  @override
  String get editFontSubstitutedDismiss =>
      isolate(super.editFontSubstitutedDismiss);

  @override
  String get saveAsTitle => isolate(super.saveAsTitle);

  @override
  String get saveAsName => isolate(super.saveAsName);

  @override
  String get saveAsNameEmpty => isolate(super.saveAsNameEmpty);

  @override
  String get saveAsNameInvalid => isolate(super.saveAsNameInvalid);

  @override
  String get saveAsNameTaken => isolate(super.saveAsNameTaken);

  @override
  String get saveAsWhere => isolate(super.saveAsWhere);

  @override
  String get saveAsOtherLocation => isolate(super.saveAsOtherLocation);

  @override
  String get saveAsFormat => isolate(super.saveAsFormat);

  @override
  String get saveAsPdf => isolate(super.saveAsPdf);

  @override
  String get saveAsPdfDescription => isolate(super.saveAsPdfDescription);

  @override
  String get saveAsPdfA => isolate(super.saveAsPdfA);

  @override
  String get saveAsWeb => isolate(super.saveAsWeb);

  @override
  String get saveAsCopy => isolate(super.saveAsCopy);

  @override
  String saveAsCopyDescription(String name, String folder) =>
      isolate(super.saveAsCopyDescription(name, folder));

  @override
  String get saveAsComments => isolate(super.saveAsComments);

  @override
  String get saveAsHistory => isolate(super.saveAsHistory);

  @override
  String get saveAsCancel => isolate(super.saveAsCancel);

  @override
  String get saveAsClose => isolate(super.saveAsClose);

  @override
  String saveFailedTitle(String name) => isolate(super.saveFailedTitle(name));

  @override
  String get saveFailedDiskFull => isolate(super.saveFailedDiskFull);

  @override
  String get saveFailedPermission => isolate(super.saveFailedPermission);

  @override
  String get saveFailedLocked => isolate(super.saveFailedLocked);

  @override
  String get saveFailedRename => isolate(super.saveFailedRename);

  @override
  String get saveFailedVolume => isolate(super.saveFailedVolume);

  @override
  String get saveFailedHardLinked => isolate(super.saveFailedHardLinked);

  @override
  String get saveFailedNotOwner => isolate(super.saveFailedNotOwner);

  @override
  String get saveFailedOther => isolate(super.saveFailedOther);

  @override
  String get saveFailedNoRecoveryCopy =>
      isolate(super.saveFailedNoRecoveryCopy);

  @override
  String get saveTryAgain => isolate(super.saveTryAgain);

  @override
  String get saveSomewhereElse => isolate(super.saveSomewhereElse);

  @override
  String get saveAsEllipsis => isolate(super.saveAsEllipsis);

  @override
  String get saveToastDiskFull => isolate(super.saveToastDiskFull);

  @override
  String get saveToastOther => isolate(super.saveToastOther);

  @override
  String get saveToastDismiss => isolate(super.saveToastDismiss);

  @override
  String fileChangedTitle(String name) => isolate(super.fileChangedTitle(name));

  @override
  String get fileChangedBody => isolate(super.fileChangedBody);

  @override
  String get fileChangedCompare => isolate(super.fileChangedCompare);

  @override
  String get fileChangedKeepMine => isolate(super.fileChangedKeepMine);

  @override
  String get fileChangedReload => isolate(super.fileChangedReload);

  @override
  String optimizeTitle(String name) => isolate(super.optimizeTitle(name));

  @override
  String get optimizeSignedBody => isolate(super.optimizeSignedBody);

  @override
  String get optimizeAction => isolate(super.optimizeAction);

  @override
  String get saveAsNameInvalidWindows =>
      isolate(super.saveAsNameInvalidWindows);

  @override
  String get saveAsNameOpen => isolate(super.saveAsNameOpen);

  @override
  String saveAsCopyDescriptionHere(String name) =>
      isolate(super.saveAsCopyDescriptionHere(name));

  @override
  String readOnlyFileTitle(String name) =>
      isolate(super.readOnlyFileTitle(name));

  @override
  String get readOnlyFileBody => isolate(super.readOnlyFileBody);

  @override
  String get readOnlyFileSaveCopy => isolate(super.readOnlyFileSaveCopy);

  @override
  String closeUnsavedTitle(String name) =>
      isolate(super.closeUnsavedTitle(name));

  @override
  String closeUnsavedBody(String edits) =>
      isolate(super.closeUnsavedBody(edits));

  @override
  String closingEdits(int count, String formatted) =>
      isolate(super.closingEdits(count, formatted));

  @override
  String get closeUnsavedSave => isolate(super.closeUnsavedSave);

  @override
  String get closeUnsavedDiscard => isolate(super.closeUnsavedDiscard);

  @override
  String quitReviewTitle(int count, String formatted) =>
      isolate(super.quitReviewTitle(count, formatted));

  @override
  String get quitReviewBody => isolate(super.quitReviewBody);

  @override
  String get quitReviewSave => isolate(super.quitReviewSave);

  @override
  String get quitReviewDiscard => isolate(super.quitReviewDiscard);

  @override
  String recoveryTitle(int count, String formatted) =>
      isolate(super.recoveryTitle(count, formatted));

  @override
  String get recoveryBody => isolate(super.recoveryBody);

  @override
  String get recoveryNote => isolate(super.recoveryNote);

  @override
  String get recoveryDiscard => isolate(super.recoveryDiscard);

  @override
  String recoveryOpen(int count, String formatted) =>
      isolate(super.recoveryOpen(count, formatted));

  @override
  String get recoveryChangedBadge => isolate(super.recoveryChangedBadge);

  @override
  String get recoveryChangedBody => isolate(super.recoveryChangedBody);

  @override
  String get recoveryFileSuffix => isolate(super.recoveryFileSuffix);

  @override
  String get signedTitle => isolate(super.signedTitle);

  @override
  String signedBodyBy(String name, String signer, String date) =>
      isolate(super.signedBodyBy(name, signer, date));

  @override
  String signedBody(String name, int count, String formatted) =>
      isolate(super.signedBody(name, count, formatted));

  @override
  String get signedEditCopy => isolate(super.signedEditCopy);

  @override
  String get signedEditAnyway => isolate(super.signedEditAnyway);

  @override
  String signedCopyHint(String name) => isolate(super.signedCopyHint(name));

  @override
  String signedCopyName(String stem) => isolate(super.signedCopyName(stem));

  @override
  String signedCopyNameNumbered(String stem, int number) =>
      isolate(super.signedCopyNameNumbered(stem, number));

  @override
  String signedBannerTitle(int count) =>
      isolate(super.signedBannerTitle(count));

  @override
  String signedBannerBodyBy(String signer) =>
      isolate(super.signedBannerBodyBy(signer));

  @override
  String get signedBannerBody => isolate(super.signedBannerBody);

  @override
  String get signedBannerReview => isolate(super.signedBannerReview);

  @override
  String signedReviewRow(String signer) =>
      isolate(super.signedReviewRow(signer));

  @override
  String get signedReviewRowOther => isolate(super.signedReviewRowOther);

  @override
  String get settingsEditMarks => isolate(super.settingsEditMarks);

  @override
  String get settingsEditMarksNote => isolate(super.settingsEditMarksNote);

  @override
  String get settingsMissingGlyphs => isolate(super.settingsMissingGlyphs);

  @override
  String get settingsMissingGlyphsSimilar =>
      isolate(super.settingsMissingGlyphsSimilar);

  @override
  String get settingsMissingGlyphsAsk =>
      isolate(super.settingsMissingGlyphsAsk);

  @override
  String get settingsMissingGlyphsMark =>
      isolate(super.settingsMissingGlyphsMark);

  @override
  String get settingsFontForNewText => isolate(super.settingsFontForNewText);

  @override
  String get settingsFontForNewTextMatch =>
      isolate(super.settingsFontForNewTextMatch);

  @override
  String get settingsKeepVersions => isolate(super.settingsKeepVersions);

  @override
  String get settingsKeepVersions30 => isolate(super.settingsKeepVersions30);

  @override
  String get settingsReflow => isolate(super.settingsReflow);

  @override
  String get settingsRecoveryCopies => isolate(super.settingsRecoveryCopies);

  @override
  String get settingsSaving => isolate(super.settingsSaving);

  @override
  String get settingsSavingEnd => isolate(super.settingsSavingEnd);

  @override
  String get settingsSavingEndBody => isolate(super.settingsSavingEndBody);

  @override
  String get settingsOptimize => isolate(super.settingsOptimize);

  @override
  String get settingsOptimizeBody => isolate(super.settingsOptimizeBody);

  @override
  String get settingsRecoveryFolder => isolate(super.settingsRecoveryFolder);

  @override
  String shellZoomTypeHint(String min, String max) =>
      isolate(super.shellZoomTypeHint(min, max));

  @override
  String get shellEditForbidden => isolate(super.shellEditForbidden);

  @override
  String get editPanelTipClick => isolate(super.editPanelTipClick);

  @override
  String editPanelTipKeys(String key) => isolate(super.editPanelTipKeys(key));

  @override
  String get editPanelInSession => isolate(super.editPanelInSession);

  @override
  String get editPanelReview => isolate(super.editPanelReview);

  @override
  String get languageNameGerman => isolate(super.languageNameGerman);

  @override
  String get languageNameJapanese => isolate(super.languageNameJapanese);

  @override
  String languageWithRegion(String language, String region) =>
      isolate(super.languageWithRegion(language, region));

  @override
  String get editLanguage => isolate(super.editLanguage);

  @override
  String get editCheckSpelling => isolate(super.editCheckSpelling);

  @override
  String get editHyphenate => isolate(super.editHyphenate);

  @override
  String editStepLanguage(String page) => isolate(super.editStepLanguage(page));

  @override
  String get reviewClose => isolate(super.reviewClose);

  @override
  String get reviewShow => isolate(super.reviewShow);

  @override
  String get reviewFilterAll => isolate(super.reviewFilterAll);

  @override
  String get reviewFilterText => isolate(super.reviewFilterText);

  @override
  String get reviewFilterFonts => isolate(super.reviewFilterFonts);

  @override
  String get reviewFilterWarnings => isolate(super.reviewFilterWarnings);

  @override
  String get reviewEmptyTitle => isolate(super.reviewEmptyTitle);

  @override
  String get reviewEmptyBody => isolate(super.reviewEmptyBody);

  @override
  String get reviewNothing => isolate(super.reviewNothing);

  @override
  String get reviewRevertAll => isolate(super.reviewRevertAll);

  @override
  String get reviewExportList => isolate(super.reviewExportList);

  @override
  String get reviewGoTo => isolate(super.reviewGoTo);

  @override
  String get reviewRevert => isolate(super.reviewRevert);

  @override
  String get reviewStepReverted => isolate(super.reviewStepReverted);

  @override
  String get reviewStepRevertedAll => isolate(super.reviewStepRevertedAll);

  @override
  String get reviewWhereSignature => isolate(super.reviewWhereSignature);

  @override
  String reviewWhereSignaturePage(String page) =>
      isolate(super.reviewWhereSignaturePage(page));

  @override
  String reviewWhereText(String page) => isolate(super.reviewWhereText(page));

  @override
  String reviewWhereFont(String page) => isolate(super.reviewWhereFont(page));

  @override
  String reviewWhereWarning(String page) =>
      isolate(super.reviewWhereWarning(page));

  @override
  String reviewExportName(String name) => isolate(super.reviewExportName(name));

  @override
  String get reviewExportFailed => isolate(super.reviewExportFailed);

  @override
  String reviewRevertAllBody(String name) =>
      isolate(super.reviewRevertAllBody(name));

  @override
  String reviewDependentBody(String later, String change) =>
      isolate(super.reviewDependentBody(later, change));

  @override
  String reviewDependentsBody(int count, String shown, String change) =>
      isolate(super.reviewDependentsBody(count, shown, change));

  @override
  String reviewKeptWarning(int count, String shown) =>
      isolate(super.reviewKeptWarning(count, shown));

  @override
  String reviewRevertAllTitle(int count, String shown) =>
      isolate(super.reviewRevertAllTitle(count, shown));

  @override
  String reviewRevertAllButton(int count, String shown) =>
      isolate(super.reviewRevertAllButton(count, shown));

  @override
  String reviewDependentTitle(int count, String shown) =>
      isolate(super.reviewDependentTitle(count, shown));

  @override
  String reviewDependentButton(int count, String shown) =>
      isolate(super.reviewDependentButton(count, shown));

  @override
  String get editPanelTitle => isolate(super.editPanelTitle);

  @override
  String get editPanelText => isolate(super.editPanelText);

  @override
  String get editPanelSize => isolate(super.editPanelSize);

  @override
  String get editPanelColour => isolate(super.editPanelColour);

  @override
  String get editPanelColoursDocument =>
      isolate(super.editPanelColoursDocument);

  @override
  String get editPanelColoursStandard =>
      isolate(super.editPanelColoursStandard);

  @override
  String get editPanelFontsDocument => isolate(super.editPanelFontsDocument);

  @override
  String get editPanelFontsDevice => isolate(super.editPanelFontsDevice);

  @override
  String get editPanelBold => isolate(super.editPanelBold);

  @override
  String get editPanelItalic => isolate(super.editPanelItalic);

  @override
  String get editPanelUnderline => isolate(super.editPanelUnderline);

  @override
  String get editPanelNoBold => isolate(super.editPanelNoBold);

  @override
  String get editPanelNoItalic => isolate(super.editPanelNoItalic);

  @override
  String get editPanelNoUnderline => isolate(super.editPanelNoUnderline);

  @override
  String get editPanelAlignment => isolate(super.editPanelAlignment);

  @override
  String get editPanelAlignLeft => isolate(super.editPanelAlignLeft);

  @override
  String get editPanelAlignCenter => isolate(super.editPanelAlignCenter);

  @override
  String get editPanelAlignRight => isolate(super.editPanelAlignRight);

  @override
  String get editPanelAlignJustify => isolate(super.editPanelAlignJustify);

  @override
  String get editPanelSpacing => isolate(super.editPanelSpacing);

  @override
  String get editPanelCharacter => isolate(super.editPanelCharacter);

  @override
  String get editPanelLine => isolate(super.editPanelLine);

  @override
  String get editPanelBefore => isolate(super.editPanelBefore);

  @override
  String get editPanelAfter => isolate(super.editPanelAfter);

  @override
  String get editPanelPosition => isolate(super.editPanelPosition);

  @override
  String get editPanelWidth => isolate(super.editPanelWidth);

  @override
  String get editPanelHeight => isolate(super.editPanelHeight);

  @override
  String get editPanelReset => isolate(super.editPanelReset);

  @override
  String get editPanelHint => isolate(super.editPanelHint);

  @override
  String get editBarLabel => isolate(super.editBarLabel);

  @override
  String get editBarLink => isolate(super.editBarLink);

  @override
  String get editBarHighlight => isolate(super.editBarHighlight);

  @override
  String get editBarComment => isolate(super.editBarComment);

  @override
  String get editBarReplace => isolate(super.editBarReplace);

  @override
  String editStepStyle(String page) => isolate(super.editStepStyle(page));

  @override
  String editStepMoved(String page) => isolate(super.editStepMoved(page));

  @override
  String editStepResized(String page) => isolate(super.editStepResized(page));

  @override
  String get phoneSections => isolate(super.phoneSections);

  @override
  String get phoneTabHome => isolate(super.phoneTabHome);

  @override
  String get phoneTabFiles => isolate(super.phoneTabFiles);

  @override
  String get phoneTabScan => isolate(super.phoneTabScan);

  @override
  String get phoneTabSettings => isolate(super.phoneTabSettings);

  @override
  String jobPageOf(String page, String pages) =>
      isolate(super.jobPageOf(page, pages));

  @override
  String jobPausedAtPage(String page) => isolate(super.jobPausedAtPage(page));

  @override
  String get jobFailedDiskFull => isolate(super.jobFailedDiskFull);

  @override
  String jobCopyingTitle(String name) => isolate(super.jobCopyingTitle(name));

  @override
  String jobCopiedTitle(String name) => isolate(super.jobCopiedTitle(name));

  @override
  String jobCopyFailedTitle(String name) =>
      isolate(super.jobCopyFailedTitle(name));

  @override
  String get tasksTitle => isolate(super.tasksTitle);

  @override
  String get tasksClose => isolate(super.tasksClose);

  @override
  String get tasksOpen => isolate(super.tasksOpen);

  @override
  String get tasksEmptyTitle => isolate(super.tasksEmptyTitle);

  @override
  String get tasksEmptyBody => isolate(super.tasksEmptyBody);

  @override
  String tasksRunning(int count, String formatted) =>
      isolate(super.tasksRunning(count, formatted));

  @override
  String get taskPause => isolate(super.taskPause);

  @override
  String get taskResume => isolate(super.taskResume);

  @override
  String get taskShow => isolate(super.taskShow);

  @override
  String get taskDismiss => isolate(super.taskDismiss);

  @override
  String taskCancelTitle(String task) => isolate(super.taskCancelTitle(task));

  @override
  String get taskCancelBody => isolate(super.taskCancelBody);

  @override
  String get taskKeepRunning => isolate(super.taskKeepRunning);

  @override
  String get taskCancelConfirm => isolate(super.taskCancelConfirm);

  @override
  String tasksQuitTitle(int count, String formatted) =>
      isolate(super.tasksQuitTitle(count, formatted));

  @override
  String get tasksQuitBody => isolate(super.tasksQuitBody);

  @override
  String get tasksQuitKeep => isolate(super.tasksQuitKeep);

  @override
  String get tasksQuitConfirm => isolate(super.tasksQuitConfirm);

  @override
  String get organizeGridLabel => isolate(super.organizeGridLabel);

  @override
  String get organizePanelLabel => isolate(super.organizePanelLabel);

  @override
  String organizeHintSelected(int total, String selected, String pages) =>
      isolate(super.organizeHintSelected(total, selected, pages));

  @override
  String organizeHintMoving(int count, String n) =>
      isolate(super.organizeHintMoving(count, n));

  @override
  String organizePanelTitle(int count, String n) =>
      isolate(super.organizePanelTitle(count, n));

  @override
  String get organizePanelPages => isolate(super.organizePanelPages);

  @override
  String organizePanelPagesLabels(String pages, String labels) =>
      isolate(super.organizePanelPagesLabels(pages, labels));

  @override
  String get organizePanelSize => isolate(super.organizePanelSize);

  @override
  String get organizePanelRotation => isolate(super.organizePanelRotation);

  @override
  String get organizePanelMixed => isolate(super.organizePanelMixed);

  @override
  String get organizePanelCommands => isolate(super.organizePanelCommands);

  @override
  String get organizePanelExtract => isolate(super.organizePanelExtract);

  @override
  String get organizePanelReplace => isolate(super.organizePanelReplace);

  @override
  String organizePanelInsertAfter(String page) =>
      isolate(super.organizePanelInsertAfter(page));

  @override
  String get organizePanelBlankPage => isolate(super.organizePanelBlankPage);

  @override
  String get organizePanelFromFile => isolate(super.organizePanelFromFile);

  @override
  String get organizePanelFromScanner =>
      isolate(super.organizePanelFromScanner);

  @override
  String organizePagesCount(int count, String n) =>
      isolate(super.organizePagesCount(count, n));

  @override
  String get organizeMenuExtract => isolate(super.organizeMenuExtract);

  @override
  String get organizeMenuInsertBlank => isolate(super.organizeMenuInsertBlank);

  @override
  String get organizeMenuInsertFile => isolate(super.organizeMenuInsertFile);

  @override
  String get organizeMenuReplace => isolate(super.organizeMenuReplace);

  @override
  String organizeMenuDelete(int count, String n) =>
      isolate(super.organizeMenuDelete(count, n));

  @override
  String get organizeDeleteAllReason => isolate(super.organizeDeleteAllReason);

  @override
  String organizeToastDeleted(int count, String n) =>
      isolate(super.organizeToastDeleted(count, n));

  @override
  String organizeToastRotated(int count, String n) =>
      isolate(super.organizeToastRotated(count, n));

  @override
  String organizeToastDuplicated(int count, String n) =>
      isolate(super.organizeToastDuplicated(count, n));

  @override
  String organizeToastMoved(int count, String n) =>
      isolate(super.organizeToastMoved(count, n));

  @override
  String organizeToastInserted(int count, String n) =>
      isolate(super.organizeToastInserted(count, n));

  @override
  String organizeToastPages(int count, String pages) =>
      isolate(super.organizeToastPages(count, pages));

  @override
  String organizeToastDeletedNote(int count, String pages) =>
      isolate(super.organizeToastDeletedNote(count, pages));

  @override
  String organizeStepInsert(String name) =>
      isolate(super.organizeStepInsert(name));

  @override
  String get organizeFailed => isolate(super.organizeFailed);

  @override
  String organizeInsertFailed(String name) =>
      isolate(super.organizeInsertFailed(name));

  @override
  String organizeDropMoveBefore(int count, String pages, String before) =>
      isolate(super.organizeDropMoveBefore(count, pages, before));

  @override
  String organizeDropMoveEnd(int count, String pages) =>
      isolate(super.organizeDropMoveEnd(count, pages));

  @override
  String organizeDropFilesBefore(String before) =>
      isolate(super.organizeDropFilesBefore(before));

  @override
  String get organizeDropFilesEnd => isolate(super.organizeDropFilesEnd);

  @override
  String jobInsertingTitle(String name) =>
      isolate(super.jobInsertingTitle(name));

  @override
  String jobInsertedTitle(String name) => isolate(super.jobInsertedTitle(name));

  @override
  String get organizeSelectFirst => isolate(super.organizeSelectFirst);

  @override
  String get organizeCancel => isolate(super.organizeCancel);

  @override
  String get organizeFailedTitle => isolate(super.organizeFailedTitle);

  @override
  String organizeBadRange(String last) => isolate(super.organizeBadRange(last));

  @override
  String organizeSizeA4(String size) => isolate(super.organizeSizeA4(size));

  @override
  String organizeSizeLetter(String size) =>
      isolate(super.organizeSizeLetter(size));

  @override
  String get organizeSizeCustom => isolate(super.organizeSizeCustom);

  @override
  String get organizeWidth => isolate(super.organizeWidth);

  @override
  String get organizeHeight => isolate(super.organizeHeight);

  @override
  String get cropTitle => isolate(super.cropTitle);

  @override
  String get cropMargins => isolate(super.cropMargins);

  @override
  String get cropTop => isolate(super.cropTop);

  @override
  String get cropBottom => isolate(super.cropBottom);

  @override
  String get cropLeft => isolate(super.cropLeft);

  @override
  String get cropRight => isolate(super.cropRight);

  @override
  String get cropRemoveWhite => isolate(super.cropRemoveWhite);

  @override
  String get cropNoContent => isolate(super.cropNoContent);

  @override
  String cropTooMuch(String page) => isolate(super.cropTooMuch(page));

  @override
  String get cropPageSize => isolate(super.cropPageSize);

  @override
  String cropKeepSize(String size) => isolate(super.cropKeepSize(size));

  @override
  String get cropContent => isolate(super.cropContent);

  @override
  String get cropFitCentre => isolate(super.cropFitCentre);

  @override
  String get cropFitScale => isolate(super.cropFitScale);

  @override
  String get cropApplyTo => isolate(super.cropApplyTo);

  @override
  String get cropThisPage => isolate(super.cropThisPage);

  @override
  String cropAllPages(int count, String formatted) =>
      isolate(super.cropAllPages(count, formatted));

  @override
  String get cropSomePages => isolate(super.cropSomePages);

  @override
  String get cropWhichPages => isolate(super.cropWhichPages);

  @override
  String get cropParityAll => isolate(super.cropParityAll);

  @override
  String get cropParityOdd => isolate(super.cropParityOdd);

  @override
  String get cropParityEven => isolate(super.cropParityEven);

  @override
  String cropAction(int count, String formatted) =>
      isolate(super.cropAction(count, formatted));

  @override
  String cropResizeAction(int count, String formatted) =>
      isolate(super.cropResizeAction(count, formatted));

  @override
  String cropDone(int count, String formatted) =>
      isolate(super.cropDone(count, formatted));

  @override
  String get cropDoneHidden => isolate(super.cropDoneHidden);

  @override
  String get cropStep => isolate(super.cropStep);

  @override
  String get cropSizeStep => isolate(super.cropSizeStep);

  @override
  String get labelsTitle => isolate(super.labelsTitle);

  @override
  String get labelsDescription => isolate(super.labelsDescription);

  @override
  String get labelsColumnPages => isolate(super.labelsColumnPages);

  @override
  String get labelsColumnStyle => isolate(super.labelsColumnStyle);

  @override
  String get labelsColumnPrefix => isolate(super.labelsColumnPrefix);

  @override
  String get labelsColumnStart => isolate(super.labelsColumnStart);

  @override
  String get labelsPrefixNone => isolate(super.labelsPrefixNone);

  @override
  String get labelsStyleRomanLower => isolate(super.labelsStyleRomanLower);

  @override
  String get labelsStyleRomanUpper => isolate(super.labelsStyleRomanUpper);

  @override
  String get labelsStyleDecimal => isolate(super.labelsStyleDecimal);

  @override
  String get labelsStyleLettersLower => isolate(super.labelsStyleLettersLower);

  @override
  String get labelsStyleLettersUpper => isolate(super.labelsStyleLettersUpper);

  @override
  String get labelsStyleNone => isolate(super.labelsStyleNone);

  @override
  String get labelsRemoveRange => isolate(super.labelsRemoveRange);

  @override
  String get labelsAddRange => isolate(super.labelsAddRange);

  @override
  String get labelsPreview => isolate(super.labelsPreview);

  @override
  String get labelsPrint => isolate(super.labelsPrint);

  @override
  String get labelsPrintNote => isolate(super.labelsPrintNote);

  @override
  String get labelsApply => isolate(super.labelsApply);

  @override
  String get labelsStep => isolate(super.labelsStep);

  @override
  String labelsErrorInvalid(String row) =>
      isolate(super.labelsErrorInvalid(row));

  @override
  String labelsErrorOverlap(String row) =>
      isolate(super.labelsErrorOverlap(row));

  @override
  String labelsErrorPast(String row, String last) =>
      isolate(super.labelsErrorPast(row, last));

  @override
  String labelsErrorUncovered(String page) =>
      isolate(super.labelsErrorUncovered(page));

  @override
  String get insertMenuBlank => isolate(super.insertMenuBlank);

  @override
  String get insertMenuFile => isolate(super.insertMenuFile);

  @override
  String get insertMenuScan => isolate(super.insertMenuScan);

  @override
  String get insertBlankTitle => isolate(super.insertBlankTitle);

  @override
  String get insertSize => isolate(super.insertSize);

  @override
  String insertSameSize(String page, String size) =>
      isolate(super.insertSameSize(page, size));

  @override
  String get insertOrientation => isolate(super.insertOrientation);

  @override
  String get insertPortrait => isolate(super.insertPortrait);

  @override
  String get insertLandscape => isolate(super.insertLandscape);

  @override
  String get insertCount => isolate(super.insertCount);

  @override
  String get insertPosition => isolate(super.insertPosition);

  @override
  String get insertBefore => isolate(super.insertBefore);

  @override
  String get insertAfter => isolate(super.insertAfter);

  @override
  String get insertPage => isolate(super.insertPage);

  @override
  String insertAction(int count, String formatted) =>
      isolate(super.insertAction(count, formatted));

  @override
  String get insertBlankStep => isolate(super.insertBlankStep);

  @override
  String get insertFileTitle => isolate(super.insertFileTitle);

  @override
  String get insertFileAction => isolate(super.insertFileAction);

  @override
  String get insertFileStep => isolate(super.insertFileStep);

  @override
  String get sourceChoose => isolate(super.sourceChoose);

  @override
  String get sourceNone => isolate(super.sourceNone);

  @override
  String sourcePagesInfo(int count, String name, String formatted) =>
      isolate(super.sourcePagesInfo(count, name, formatted));

  @override
  String get sourceRange => isolate(super.sourceRange);

  @override
  String get sourceAllPages => isolate(super.sourceAllPages);

  @override
  String get sourceUnlock => isolate(super.sourceUnlock);

  @override
  String get sourceForbidden => isolate(super.sourceForbidden);

  @override
  String get sourceUnreadable => isolate(super.sourceUnreadable);

  @override
  String get replaceTitle => isolate(super.replaceTitle);

  @override
  String get replaceThese => isolate(super.replaceThese);

  @override
  String get replaceFewer => isolate(super.replaceFewer);

  @override
  String get replaceMore => isolate(super.replaceMore);

  @override
  String replaceAction(int count, String formatted) =>
      isolate(super.replaceAction(count, formatted));

  @override
  String get replaceStep => isolate(super.replaceStep);

  @override
  String get extractTitle => isolate(super.extractTitle);

  @override
  String get extractPages => isolate(super.extractPages);

  @override
  String get extractOneFile => isolate(super.extractOneFile);

  @override
  String get extractEachFile => isolate(super.extractEachFile);

  @override
  String get extractDelete => isolate(super.extractDelete);

  @override
  String get extractDeleteAll => isolate(super.extractDeleteAll);

  @override
  String get extractAction => isolate(super.extractAction);

  @override
  String extractFileName(String document, String pages) =>
      isolate(super.extractFileName(document, pages));

  @override
  String get extractDeleteStep => isolate(super.extractDeleteStep);

  @override
  String jobExtractingTitle(String name) =>
      isolate(super.jobExtractingTitle(name));

  @override
  String jobExtractedTitle(String name) =>
      isolate(super.jobExtractedTitle(name));

  @override
  String jobExtractFailedTitle(String name) =>
      isolate(super.jobExtractFailedTitle(name));

  @override
  String jobInsertFailedTitle(String name) =>
      isolate(super.jobInsertFailedTitle(name));

  @override
  String jobReplacingTitle(String name) =>
      isolate(super.jobReplacingTitle(name));

  @override
  String jobReplacedTitle(String name) => isolate(super.jobReplacedTitle(name));

  @override
  String jobReplaceFailedTitle(String name) =>
      isolate(super.jobReplaceFailedTitle(name));

  @override
  String organizeFileCount(int count, String formatted) =>
      isolate(super.organizeFileCount(count, formatted));

  @override
  String organizePageCount(int count, String formatted) =>
      isolate(super.organizePageCount(count, formatted));

  @override
  String get combineAddFiles => isolate(super.combineAddFiles);

  @override
  String get combineFilter => isolate(super.combineFilter);

  @override
  String get combineEmptyTitle => isolate(super.combineEmptyTitle);

  @override
  String get combineEmptyBody => isolate(super.combineEmptyBody);

  @override
  String get combineDrag => isolate(super.combineDrag);

  @override
  String get combineMoveUp => isolate(super.combineMoveUp);

  @override
  String get combineMoveDown => isolate(super.combineMoveDown);

  @override
  String get combinePagesToInclude => isolate(super.combinePagesToInclude);

  @override
  String get combineAllPages => isolate(super.combineAllPages);

  @override
  String get combineRemoveFile => isolate(super.combineRemoveFile);

  @override
  String get combineMetaImage => isolate(super.combineMetaImage);

  @override
  String get combineMetaOffice => isolate(super.combineMetaOffice);

  @override
  String get combineNeedsPassword => isolate(super.combineNeedsPassword);

  @override
  String get combineWrongPassword => isolate(super.combineWrongPassword);

  @override
  String get combineOwnerPassword => isolate(super.combineOwnerPassword);

  @override
  String get combineUnreadable => isolate(super.combineUnreadable);

  @override
  String get combineBadRange => isolate(super.combineBadRange);

  @override
  String get combinePassword => isolate(super.combinePassword);

  @override
  String get combineUnlock => isolate(super.combineUnlock);

  @override
  String get combineNotProtected => isolate(super.combineNotProtected);

  @override
  String get combineNotSigned => isolate(super.combineNotSigned);

  @override
  String get combineNewFile => isolate(super.combineNewFile);

  @override
  String get combineDefaultName => isolate(super.combineDefaultName);

  @override
  String get combineBookmarks => isolate(super.combineBookmarks);

  @override
  String get combineKeepForms => isolate(super.combineKeepForms);

  @override
  String get combineKeepFormsNote => isolate(super.combineKeepFormsNote);

  @override
  String combineAbout(String size) => isolate(super.combineAbout(size));

  @override
  String combineAction(int count, String formatted) =>
      isolate(super.combineAction(count, formatted));

  @override
  String combineResult(int count, String formatted) =>
      isolate(super.combineResult(count, formatted));

  @override
  String combineResultPage(String page, String file) =>
      isolate(super.combineResultPage(page, file));

  @override
  String combineOutputExists(String name) =>
      isolate(super.combineOutputExists(name));

  @override
  String splitTitle(String name) => isolate(super.splitTitle(name));

  @override
  String get splitBy => isolate(super.splitBy);

  @override
  String get splitEvery => isolate(super.splitEvery);

  @override
  String get splitEveryBody => isolate(super.splitEveryBody);

  @override
  String get splitBookmarks => isolate(super.splitBookmarks);

  @override
  String splitBookmarksBody(int count, String formatted) =>
      isolate(super.splitBookmarksBody(count, formatted));

  @override
  String get splitNoBookmarks => isolate(super.splitNoBookmarks);

  @override
  String get splitSize => isolate(super.splitSize);

  @override
  String get splitSizeBody => isolate(super.splitSizeBody);

  @override
  String get splitBlank => isolate(super.splitBlank);

  @override
  String get splitBlankBody => isolate(super.splitBlankBody);

  @override
  String get splitNoBlankPages => isolate(super.splitNoBlankPages);

  @override
  String get splitPagesPerFile => isolate(super.splitPagesPerFile);

  @override
  String get splitLargest => isolate(super.splitLargest);

  @override
  String get splitFileNames => isolate(super.splitFileNames);

  @override
  String get splitSaveTo => isolate(super.splitSaveTo);

  @override
  String get splitSameFolder => isolate(super.splitSameFolder);

  @override
  String get splitChooseFolder => isolate(super.splitChooseFolder);

  @override
  String get splitOverLimit => isolate(super.splitOverLimit);

  @override
  String get splitNotProtected => isolate(super.splitNotProtected);

  @override
  String get splitNotSigned => isolate(super.splitNotSigned);

  @override
  String splitAction(int count, String formatted) =>
      isolate(super.splitAction(count, formatted));

  @override
  String get createBlank => isolate(super.createBlank);

  @override
  String get createFromFiles => isolate(super.createFromFiles);

  @override
  String get createFromClipboard => isolate(super.createFromClipboard);

  @override
  String get createDefaultName => isolate(super.createDefaultName);

  @override
  String jobSplittingTitle(String name) =>
      isolate(super.jobSplittingTitle(name));

  @override
  String jobSplitTitle(String name) => isolate(super.jobSplitTitle(name));

  @override
  String jobSplitFailedTitle(String name) =>
      isolate(super.jobSplitFailedTitle(name));

  @override
  String jobCombiningTitle(String name) =>
      isolate(super.jobCombiningTitle(name));

  @override
  String jobCombinedTitle(String name) => isolate(super.jobCombinedTitle(name));

  @override
  String jobCombineFailedTitle(String name) =>
      isolate(super.jobCombineFailedTitle(name));

  @override
  String jobCreatingTitle(String name) => isolate(super.jobCreatingTitle(name));

  @override
  String jobCreatedTitle(String name) => isolate(super.jobCreatedTitle(name));

  @override
  String jobCreateFailedTitle(String name) =>
      isolate(super.jobCreateFailedTitle(name));

  @override
  String get commentsTitle => isolate(super.commentsTitle);

  @override
  String get commentsFilter => isolate(super.commentsFilter);

  @override
  String get commentsMore => isolate(super.commentsMore);

  @override
  String get commentsStatus => isolate(super.commentsStatus);

  @override
  String commentsStatusOpen(String count) =>
      isolate(super.commentsStatusOpen(count));

  @override
  String commentsStatusResolved(String count) =>
      isolate(super.commentsStatusResolved(count));

  @override
  String commentsStatusAll(String count) =>
      isolate(super.commentsStatusAll(count));

  @override
  String get commentsFilterAuthor => isolate(super.commentsFilterAuthor);

  @override
  String get commentsFilterType => isolate(super.commentsFilterType);

  @override
  String get commentsFilterSort => isolate(super.commentsFilterSort);

  @override
  String get commentsAllPeople => isolate(super.commentsAllPeople);

  @override
  String get commentsTypeNotes => isolate(super.commentsTypeNotes);

  @override
  String get commentsTypeMarkup => isolate(super.commentsTypeMarkup);

  @override
  String get commentsTypeDrawings => isolate(super.commentsTypeDrawings);

  @override
  String get commentsTypeStamps => isolate(super.commentsTypeStamps);

  @override
  String get commentsTypeOther => isolate(super.commentsTypeOther);

  @override
  String get commentsSortNewest => isolate(super.commentsSortNewest);

  @override
  String get commentsSortAuthor => isolate(super.commentsSortAuthor);

  @override
  String get commentsSortOther => isolate(super.commentsSortOther);

  @override
  String get commentsCertifiedNote => isolate(super.commentsCertifiedNote);

  @override
  String get commentsTruncated => isolate(super.commentsTruncated);

  @override
  String get commentsEmptyTitle => isolate(super.commentsEmptyTitle);

  @override
  String get commentsEmptyBody => isolate(super.commentsEmptyBody);

  @override
  String get commentsNoMatchTitle => isolate(super.commentsNoMatchTitle);

  @override
  String get commentsNoMatchBody => isolate(super.commentsNoMatchBody);

  @override
  String get commentsFootnote => isolate(super.commentsFootnote);

  @override
  String get commentsExportSummary => isolate(super.commentsExportSummary);

  @override
  String get commentsFlatten => isolate(super.commentsFlatten);

  @override
  String get commentsHideAll => isolate(super.commentsHideAll);

  @override
  String commentsHidden(int count, String shown) =>
      isolate(super.commentsHidden(count, shown));

  @override
  String get commentKindHighlight => isolate(super.commentKindHighlight);

  @override
  String get commentKindUnderline => isolate(super.commentKindUnderline);

  @override
  String get commentKindStrikeOut => isolate(super.commentKindStrikeOut);

  @override
  String get commentKindSquiggly => isolate(super.commentKindSquiggly);

  @override
  String get commentKindNote => isolate(super.commentKindNote);

  @override
  String get commentKindFreeText => isolate(super.commentKindFreeText);

  @override
  String get commentKindCallout => isolate(super.commentKindCallout);

  @override
  String get commentKindInk => isolate(super.commentKindInk);

  @override
  String get commentKindSquare => isolate(super.commentKindSquare);

  @override
  String get commentKindCircle => isolate(super.commentKindCircle);

  @override
  String get commentKindLine => isolate(super.commentKindLine);

  @override
  String get commentKindPolygon => isolate(super.commentKindPolygon);

  @override
  String get commentKindStamp => isolate(super.commentKindStamp);

  @override
  String get commentKindOther => isolate(super.commentKindOther);

  @override
  String commentStyleBar(String kind) => isolate(super.commentStyleBar(kind));

  @override
  String get commentStrokeWidth => isolate(super.commentStrokeWidth);

  @override
  String get commentOpacity => isolate(super.commentOpacity);

  @override
  String get commentOpen => isolate(super.commentOpen);

  @override
  String get commentDelete => isolate(super.commentDelete);

  @override
  String get commentMenu => isolate(super.commentMenu);

  @override
  String get commentEditText => isolate(super.commentEditText);

  @override
  String get commentMore => isolate(super.commentMore);

  @override
  String get commentCloseNote => isolate(super.commentCloseNote);

  @override
  String commentNoteFrom(String author) =>
      isolate(super.commentNoteFrom(author));

  @override
  String get commentReply => isolate(super.commentReply);

  @override
  String get commentResolve => isolate(super.commentResolve);

  @override
  String get commentReopen => isolate(super.commentReopen);

  @override
  String get commentPeople => isolate(super.commentPeople);

  @override
  String commentQuote(String text) => isolate(super.commentQuote(text));

  @override
  String commentReplies(int count, String shown) =>
      isolate(super.commentReplies(count, shown));

  @override
  String commentResolvedBy(String name, String time) =>
      isolate(super.commentResolvedBy(name, time));

  @override
  String get commentYesterday => isolate(super.commentYesterday);

  @override
  String commentCardLabel(
    String author,
    String kind,
    String page,
    int resolved,
    int count,
    String shown,
  ) => isolate(
    super.commentCardLabel(author, kind, page, resolved, count, shown),
  );

  @override
  String get commentStepAdd => isolate(super.commentStepAdd);

  @override
  String get commentStepChange => isolate(super.commentStepChange);

  @override
  String get commentStepDelete => isolate(super.commentStepDelete);

  @override
  String get commentStepReply => isolate(super.commentStepReply);

  @override
  String get commentStepResolve => isolate(super.commentStepResolve);

  @override
  String get commentStepReopen => isolate(super.commentStepReopen);

  @override
  String get commentDeletedToast => isolate(super.commentDeletedToast);

  @override
  String get commentDeletedNote => isolate(super.commentDeletedNote);

  @override
  String get commentNameTitle => isolate(super.commentNameTitle);

  @override
  String get commentNameBody => isolate(super.commentNameBody);

  @override
  String get commentNameSave => isolate(super.commentNameSave);

  @override
  String get settingsCommenterName => isolate(super.settingsCommenterName);

  @override
  String get commentTextField => isolate(super.commentTextField);

  @override
  String get commentSummaryFile => isolate(super.commentSummaryFile);

  @override
  String get commentColumnPage => isolate(super.commentColumnPage);

  @override
  String get commentColumnType => isolate(super.commentColumnType);

  @override
  String get commentColumnAuthor => isolate(super.commentColumnAuthor);

  @override
  String get commentColumnDate => isolate(super.commentColumnDate);

  @override
  String get commentColumnText => isolate(super.commentColumnText);

  @override
  String get commentColumnReplies => isolate(super.commentColumnReplies);

  @override
  String get commentColumnStatus => isolate(super.commentColumnStatus);

  @override
  String get commentStatusOpen => isolate(super.commentStatusOpen);

  @override
  String get commentStatusResolved => isolate(super.commentStatusResolved);

  @override
  String jobSummaryRunningTitle(String name) =>
      isolate(super.jobSummaryRunningTitle(name));

  @override
  String jobSummaryDoneTitle(String name) =>
      isolate(super.jobSummaryDoneTitle(name));

  @override
  String jobSummaryFailedTitle(String name) =>
      isolate(super.jobSummaryFailedTitle(name));

  @override
  String get commentSummaryCsvFile => isolate(super.commentSummaryCsvFile);

  @override
  String get summaryTitle => isolate(super.summaryTitle);

  @override
  String get summaryFormat => isolate(super.summaryFormat);

  @override
  String get summaryCsv => isolate(super.summaryCsv);

  @override
  String get summaryLayout => isolate(super.summaryLayout);

  @override
  String get summaryPageAndComments => isolate(super.summaryPageAndComments);

  @override
  String get summaryPageAndCommentsHint =>
      isolate(super.summaryPageAndCommentsHint);

  @override
  String get summaryCommentsOnly => isolate(super.summaryCommentsOnly);

  @override
  String get summaryCommentsOnlyHint => isolate(super.summaryCommentsOnlyHint);

  @override
  String get summaryPageThenList => isolate(super.summaryPageThenList);

  @override
  String get summaryPageThenListHint => isolate(super.summaryPageThenListHint);

  @override
  String summaryOpen(String count) => isolate(super.summaryOpen(count));

  @override
  String get summaryReplies => isolate(super.summaryReplies);

  @override
  String summaryResolved(String count) => isolate(super.summaryResolved(count));

  @override
  String get summaryEmptyPages => isolate(super.summaryEmptyPages);

  @override
  String get summarySortBy => isolate(super.summarySortBy);

  @override
  String get summarySortPage => isolate(super.summarySortPage);

  @override
  String get summaryPaper => isolate(super.summaryPaper);

  @override
  String get summaryPreview => isolate(super.summaryPreview);

  @override
  String get summaryExport => isolate(super.summaryExport);

  @override
  String get jobSummaryPageUnsupported =>
      isolate(super.jobSummaryPageUnsupported);

  @override
  String flattenTitle(int count, String formatted) =>
      isolate(super.flattenTitle(count, formatted));

  @override
  String get flattenBody => isolate(super.flattenBody);

  @override
  String flattenAll(int count, String formatted) =>
      isolate(super.flattenAll(count, formatted));

  @override
  String flattenResolved(int count, String formatted) =>
      isolate(super.flattenResolved(count, formatted));

  @override
  String get flattenKeepCopy => isolate(super.flattenKeepCopy);

  @override
  String flattenKeepCopyHint(String name) =>
      isolate(super.flattenKeepCopyHint(name));

  @override
  String flattenCopyName(String stem) => isolate(super.flattenCopyName(stem));

  @override
  String flattenCopyNameNumbered(String stem, int number) =>
      isolate(super.flattenCopyNameNumbered(stem, number));

  @override
  String flattenAction(int count, String formatted) =>
      isolate(super.flattenAction(count, formatted));

  @override
  String get commentStepFlatten => isolate(super.commentStepFlatten);

  @override
  String jobFlatteningTitle(String name) =>
      isolate(super.jobFlatteningTitle(name));

  @override
  String jobFlattenedTitle(String name) =>
      isolate(super.jobFlattenedTitle(name));

  @override
  String jobFlattenFailedTitle(String name) =>
      isolate(super.jobFlattenFailedTitle(name));

  @override
  String get jobFlattenPageUnsupported =>
      isolate(super.jobFlattenPageUnsupported);

  @override
  String sidebarSearchComment(String text) =>
      isolate(super.sidebarSearchComment(text));

  @override
  String get stampsTitle => isolate(super.stampsTitle);

  @override
  String get stampsSearch => isolate(super.stampsSearch);

  @override
  String get stampsNoMatch => isolate(super.stampsNoMatch);

  @override
  String get stampGroupStandard => isolate(super.stampGroupStandard);

  @override
  String get stampGroupNamed => isolate(super.stampGroupNamed);

  @override
  String get stampGroupMine => isolate(super.stampGroupMine);

  @override
  String get stampCreate => isolate(super.stampCreate);

  @override
  String get stampImport => isolate(super.stampImport);

  @override
  String get stampExport => isolate(super.stampExport);

  @override
  String get stampDelete => isolate(super.stampDelete);

  @override
  String get stampFileFilter => isolate(super.stampFileFilter);

  @override
  String get stampImportFailed => isolate(super.stampImportFailed);

  @override
  String get stampImportFailedBody => isolate(super.stampImportFailedBody);

  @override
  String get stampExportFailed => isolate(super.stampExportFailed);

  @override
  String get stampsFull => isolate(super.stampsFull);

  @override
  String get createStampTitle => isolate(super.createStampTitle);

  @override
  String get createStampText => isolate(super.createStampText);

  @override
  String get createStampSecondLine => isolate(super.createStampSecondLine);

  @override
  String get createStampMyName => isolate(super.createStampMyName);

  @override
  String get createStampDate => isolate(super.createStampDate);

  @override
  String get createStampTime => isolate(super.createStampTime);

  @override
  String get createStampName => isolate(super.createStampName);

  @override
  String get createStampColour => isolate(super.createStampColour);

  @override
  String get stampToneSeal => isolate(super.stampToneSeal);

  @override
  String get stampToneInk => isolate(super.stampToneInk);

  @override
  String get stampToneGreen => isolate(super.stampToneGreen);

  @override
  String get stampToneGrey => isolate(super.stampToneGrey);

  @override
  String get createStampCaps => isolate(super.createStampCaps);

  @override
  String get createStampLanguageTurkish =>
      isolate(super.createStampLanguageTurkish);

  @override
  String get createStampLanguageEnglish =>
      isolate(super.createStampLanguageEnglish);

  @override
  String get createStampLanguageGerman =>
      isolate(super.createStampLanguageGerman);

  @override
  String get createStampPreview => isolate(super.createStampPreview);

  @override
  String get createStampSavedNote => isolate(super.createStampSavedNote);

  @override
  String get createStampSave => isolate(super.createStampSave);

  @override
  String get shapeRectangle => isolate(super.shapeRectangle);

  @override
  String get shapeEllipse => isolate(super.shapeEllipse);

  @override
  String get shapeArrow => isolate(super.shapeArrow);

  @override
  String get shapeLine => isolate(super.shapeLine);

  @override
  String get shapePolygon => isolate(super.shapePolygon);

  @override
  String get shapesKeepTool => isolate(super.shapesKeepTool);

  @override
  String get stepAddShape => isolate(super.stepAddShape);

  @override
  String get stepAddStamp => isolate(super.stepAddStamp);

  @override
  String get placeStampHint => isolate(super.placeStampHint);

  @override
  String get placeShapeHint => isolate(super.placeShapeHint);

  @override
  String get placePolygonHint => isolate(super.placePolygonHint);

  @override
  String get linksTitle => isolate(super.linksTitle);

  @override
  String get linksNote => isolate(super.linksNote);

  @override
  String get linksEmpty => isolate(super.linksEmpty);

  @override
  String get linksTruncated => isolate(super.linksTruncated);

  @override
  String get linksSelectTextFirst => isolate(super.linksSelectTextFirst);

  @override
  String get linksKindWeb => isolate(super.linksKindWeb);

  @override
  String get linksKindMail => isolate(super.linksKindMail);

  @override
  String get linksKindPage => isolate(super.linksKindPage);

  @override
  String get linksKindScript => isolate(super.linksKindScript);

  @override
  String get linksKindLaunch => isolate(super.linksKindLaunch);

  @override
  String get linksKindFile => isolate(super.linksKindFile);

  @override
  String get linksKindAddress => isolate(super.linksKindAddress);

  @override
  String get linksKindAction => isolate(super.linksKindAction);

  @override
  String get linksKindNothing => isolate(super.linksKindNothing);

  @override
  String linksPage(String page) => isolate(super.linksPage(page));

  @override
  String get linksPageMissing => isolate(super.linksPageMissing);

  @override
  String linksMeta(String kind, String page) =>
      isolate(super.linksMeta(kind, page));

  @override
  String linksMetaEditing(String kind, String page) =>
      isolate(super.linksMetaEditing(kind, page));

  @override
  String get linkAddTitle => isolate(super.linkAddTitle);

  @override
  String get linkEditTitle => isolate(super.linkEditTitle);

  @override
  String get linkTo => isolate(super.linkTo);

  @override
  String get linkTypeFile => isolate(super.linkTypeFile);

  @override
  String get linkFieldWeb => isolate(super.linkFieldWeb);

  @override
  String get linkFieldMail => isolate(super.linkFieldMail);

  @override
  String get linkFieldPage => isolate(super.linkFieldPage);

  @override
  String get linkAppearance => isolate(super.linkAppearance);

  @override
  String get linkLookNone => isolate(super.linkLookNone);

  @override
  String get linkLookUnderline => isolate(super.linkLookUnderline);

  @override
  String get linkLookBox => isolate(super.linkLookBox);

  @override
  String get linkRemove => isolate(super.linkRemove);

  @override
  String get linkSave => isolate(super.linkSave);

  @override
  String get linkStepAdd => isolate(super.linkStepAdd);

  @override
  String get linkStepEdit => isolate(super.linkStepEdit);

  @override
  String get linkStepRemove => isolate(super.linkStepRemove);

  @override
  String get linkErrorWeb => isolate(super.linkErrorWeb);

  @override
  String get linkErrorMail => isolate(super.linkErrorMail);

  @override
  String get linkFailedTitle => isolate(super.linkFailedTitle);

  @override
  String get linkOpenWebTitle => isolate(super.linkOpenWebTitle);

  @override
  String get linkOpenMailTitle => isolate(super.linkOpenMailTitle);

  @override
  String get linkOpenDescription => isolate(super.linkOpenDescription);

  @override
  String get linkOpenAction => isolate(super.linkOpenAction);

  @override
  String get linkOpenFailed => isolate(super.linkOpenFailed);

  @override
  String get linkBrokenTitle => isolate(super.linkBrokenTitle);

  @override
  String get linkRefusedTitle => isolate(super.linkRefusedTitle);

  @override
  String get linkRefusedScript => isolate(super.linkRefusedScript);

  @override
  String linkRefusedLaunch(String target) =>
      isolate(super.linkRefusedLaunch(target));

  @override
  String linkRefusedFile(String target) =>
      isolate(super.linkRefusedFile(target));

  @override
  String linkRefusedAddress(String target) =>
      isolate(super.linkRefusedAddress(target));

  @override
  String get linkRefusedAction => isolate(super.linkRefusedAction);

  @override
  String linksBrokenMeta(int count, String pages) =>
      isolate(super.linksBrokenMeta(count, pages));

  @override
  String linkErrorPage(int count, String pages) =>
      isolate(super.linkErrorPage(count, pages));

  @override
  String get signPadMethod => isolate(super.signPadMethod);

  @override
  String get signPadDraw => isolate(super.signPadDraw);

  @override
  String get signPadType => isolate(super.signPadType);

  @override
  String get signPadImage => isolate(super.signPadImage);

  @override
  String get signPadArea => isolate(super.signPadArea);

  @override
  String get signPadTypeName => isolate(super.signPadTypeName);

  @override
  String get signPadNamePlaceholder => isolate(super.signPadNamePlaceholder);

  @override
  String get signPadDrawHint => isolate(super.signPadDrawHint);

  @override
  String get signPadTypeHint => isolate(super.signPadTypeHint);

  @override
  String get signPadImageHint => isolate(super.signPadImageHint);

  @override
  String get signPadChooseImage => isolate(super.signPadChooseImage);

  @override
  String get signPadInk => isolate(super.signPadInk);

  @override
  String get signPadBlack => isolate(super.signPadBlack);

  @override
  String get signPadBlue => isolate(super.signPadBlue);

  @override
  String get signPadClear => isolate(super.signPadClear);

  @override
  String get signPadSave => isolate(super.signPadSave);

  @override
  String get signDialogTitle => isolate(super.signDialogTitle);

  @override
  String get signDialogTitleInitials => isolate(super.signDialogTitleInitials);

  @override
  String get signCreate => isolate(super.signCreate);

  @override
  String get signKindSignature => isolate(super.signKindSignature);

  @override
  String get signKindInitials => isolate(super.signKindInitials);

  @override
  String get signHandwriting => isolate(super.signHandwriting);

  @override
  String get signNoStyle => isolate(super.signNoStyle);

  @override
  String get signSavedNote => isolate(super.signSavedNote);

  @override
  String get signMenuLabel => isolate(super.signMenuLabel);

  @override
  String get signMenuSignatures => isolate(super.signMenuSignatures);

  @override
  String get signMenuAdd => isolate(super.signMenuAdd);

  @override
  String get signMenuCreate => isolate(super.signMenuCreate);

  @override
  String get signMenuManage => isolate(super.signMenuManage);

  @override
  String get signDrawn => isolate(super.signDrawn);

  @override
  String get signDelete => isolate(super.signDelete);

  @override
  String get signSaveFailed => isolate(super.signSaveFailed);

  @override
  String get signImageTooLarge => isolate(super.signImageTooLarge);

  @override
  String get signImageFilter => isolate(super.signImageFilter);

  @override
  String get stepAddSignature => isolate(super.stepAddSignature);

  @override
  String get stepAddInitials => isolate(super.stepAddInitials);

  @override
  String get placeSignatureHint => isolate(super.placeSignatureHint);

  @override
  String get formPanelTitle => isolate(super.formPanelTitle);

  @override
  String get formMore => isolate(super.formMore);

  @override
  String formRequiredProgress(String filled, String total) =>
      isolate(super.formRequiredProgress(filled, total));

  @override
  String formSummaryFields(int count, String formatted) =>
      isolate(super.formSummaryFields(count, formatted));

  @override
  String formRequiredLeft(int count, String formatted) =>
      isolate(super.formRequiredLeft(count, formatted));

  @override
  String get formAllRequiredFilled => isolate(super.formAllRequiredFilled);

  @override
  String formFieldOf(String current, String total) =>
      isolate(super.formFieldOf(current, total));

  @override
  String get formHighlight => isolate(super.formHighlight);

  @override
  String get formShowOrder => isolate(super.formShowOrder);

  @override
  String get formHideOrder => isolate(super.formHideOrder);

  @override
  String get formSignedTitle => isolate(super.formSignedTitle);

  @override
  String get formSignedKeeps => isolate(super.formSignedKeeps);

  @override
  String get formSignedBreaks => isolate(super.formSignedBreaks);

  @override
  String get formFontNoticeTitle => isolate(super.formFontNoticeTitle);

  @override
  String formFontNoticeBody(String fonts) =>
      isolate(super.formFontNoticeBody(fonts));

  @override
  String get formDismiss => isolate(super.formDismiss);

  @override
  String get formRequired => isolate(super.formRequired);

  @override
  String get formMarkedField => isolate(super.formMarkedField);

  @override
  String get formClear => isolate(super.formClear);

  @override
  String get formFinish => isolate(super.formFinish);

  @override
  String get formExportData => isolate(super.formExportData);

  @override
  String get formBannerTitle => isolate(super.formBannerTitle);

  @override
  String formBannerBody(int count, String formatted, String required) =>
      isolate(super.formBannerBody(count, formatted, required));

  @override
  String get formBannerHide => isolate(super.formBannerHide);

  @override
  String get fillBannerTitle => isolate(super.fillBannerTitle);

  @override
  String get fillBannerBody => isolate(super.fillBannerBody);

  @override
  String get fillFindFields => isolate(super.fillFindFields);

  @override
  String get formPreviousField => isolate(super.formPreviousField);

  @override
  String get formNextField => isolate(super.formNextField);

  @override
  String formNavField(String current, String total) =>
      isolate(super.formNavField(current, total));

  @override
  String formNavFields(int count, String formatted) =>
      isolate(super.formNavFields(count, formatted));

  @override
  String get formNavAllFilled => isolate(super.formNavAllFilled);

  @override
  String get formSignHere => isolate(super.formSignHere);

  @override
  String formErrorTooLong(int count, String formatted) =>
      isolate(super.formErrorTooLong(count, formatted));

  @override
  String formErrorDate(String pattern) => isolate(super.formErrorDate(pattern));

  @override
  String get formErrorNumber => isolate(super.formErrorNumber);

  @override
  String formErrorRange(String min, String max) =>
      isolate(super.formErrorRange(min, max));

  @override
  String formErrorMin(String min) => isolate(super.formErrorMin(min));

  @override
  String formErrorMax(String max) => isolate(super.formErrorMax(max));

  @override
  String get formErrorRequired => isolate(super.formErrorRequired);

  @override
  String get formErrorSign => isolate(super.formErrorSign);

  @override
  String get formErrorChoose => isolate(super.formErrorChoose);

  @override
  String get formChooseDate => isolate(super.formChooseDate);

  @override
  String formDateFormat(String pattern) =>
      isolate(super.formDateFormat(pattern));

  @override
  String get formPreviousMonth => isolate(super.formPreviousMonth);

  @override
  String get formNextMonth => isolate(super.formNextMonth);

  @override
  String get formToday => isolate(super.formToday);

  @override
  String formStepFill(String name) => isolate(super.formStepFill(name));

  @override
  String get formStepClear => isolate(super.formStepClear);

  @override
  String get formStepFinish => isolate(super.formStepFinish);

  @override
  String get fillStepText => isolate(super.fillStepText);

  @override
  String get fillStepMark => isolate(super.fillStepMark);

  @override
  String get formXfaRemovedTitle => isolate(super.formXfaRemovedTitle);

  @override
  String get formXfaRemovedBody => isolate(super.formXfaRemovedBody);

  @override
  String get formFinishTitle => isolate(super.formFinishTitle);

  @override
  String get formFinishBody => isolate(super.formFinishBody);

  @override
  String get formFinishFlatten => isolate(super.formFinishFlatten);

  @override
  String get formFinishFlattenBody => isolate(super.formFinishFlattenBody);

  @override
  String get formFinishKeep => isolate(super.formFinishKeep);

  @override
  String get formFinishKeepBody => isolate(super.formFinishKeepBody);

  @override
  String get formFinishSave => isolate(super.formFinishSave);

  @override
  String get formFinishSaveAs => isolate(super.formFinishSaveAs);

  @override
  String get formClearTitle => isolate(super.formClearTitle);

  @override
  String get formClearBody => isolate(super.formClearBody);

  @override
  String get formClearConfirm => isolate(super.formClearConfirm);

  @override
  String get formFontAskTitle => isolate(super.formFontAskTitle);

  @override
  String get formFontAskBody => isolate(super.formFontAskBody);

  @override
  String get formFontAskPlex => isolate(super.formFontAskPlex);

  @override
  String get formFontAskKeep => isolate(super.formFontAskKeep);

  @override
  String get fillPanelTitle => isolate(super.fillPanelTitle);

  @override
  String get fillToolText => isolate(super.fillToolText);

  @override
  String get fillToolCheck => isolate(super.fillToolCheck);

  @override
  String get fillToolCross => isolate(super.fillToolCross);

  @override
  String get fillToolDot => isolate(super.fillToolDot);

  @override
  String get fillToolToday => isolate(super.fillToolToday);

  @override
  String get fillToolSignature => isolate(super.fillToolSignature);

  @override
  String get fillOptions => isolate(super.fillOptions);

  @override
  String get fillSnap => isolate(super.fillSnap);

  @override
  String get fillComb => isolate(super.fillComb);

  @override
  String get fillInk => isolate(super.fillInk);

  @override
  String get fillInkBlack => isolate(super.fillInkBlack);

  @override
  String get fillInkBlue => isolate(super.fillInkBlue);

  @override
  String get findNotSearchedComments => isolate(super.findNotSearchedComments);

  @override
  String sidebarSearchFormField(String text) =>
      isolate(super.sidebarSearchFormField(text));
}

final class _IsolatedFallbackLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(IsolatedFallbackLocalizations());

  @override
  bool shouldReload(_IsolatedFallbackLocalizationsDelegate old) => false;
}
