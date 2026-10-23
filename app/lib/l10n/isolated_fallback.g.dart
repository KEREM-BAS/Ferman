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
  String get onboardingLanguageSearchLabel =>
      isolate(super.onboardingLanguageSearchLabel);

  @override
  String onboardingLanguageNoMatch(String query) =>
      isolate(super.onboardingLanguageNoMatch(query));

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
  String get viewerPageNumber => isolate(super.viewerPageNumber);
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
