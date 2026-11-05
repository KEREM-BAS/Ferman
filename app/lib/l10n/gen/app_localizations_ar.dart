// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get shellHome => 'الرئيسية';

  @override
  String get shellOpenDocuments => 'المستندات المفتوحة';

  @override
  String get shellOpenFile => 'فتح ملف';

  @override
  String get shellCloseDocument => 'إغلاق المستند';

  @override
  String get shellUnsavedChanges => 'تغييرات غير محفوظة';

  @override
  String get shellOpening => 'جارٍ الفتح';

  @override
  String shellMoreDocuments(String count) {
    return '$count أخرى';
  }

  @override
  String shellMoreDocumentsBadge(String count) {
    return '+$count';
  }

  @override
  String get shellSearch => 'بحث';

  @override
  String get shellSettings => 'الإعدادات';

  @override
  String get shellModeLabel => 'الوضع';

  @override
  String get shellModeView => 'عرض';

  @override
  String get shellModeEdit => 'تحرير';

  @override
  String get shellModeComment => 'تعليق';

  @override
  String get shellModeSign => 'تعبئة وتوقيع';

  @override
  String get shellModeOrganize => 'تنظيم';

  @override
  String get shellModeConvert => 'تحويل';

  @override
  String get shellModeProtect => 'حماية';

  @override
  String get shellModeTools => 'أدوات';

  @override
  String get shellToggleSidebar => 'إظهار الشريط الجانبي أو إخفاؤه';

  @override
  String get shellTogglePanel => 'إظهار اللوحة أو إخفاؤها';

  @override
  String get shellAiAssistant => 'المساعد الذكي';

  @override
  String get shellSave => 'حفظ';

  @override
  String get shellNoChangesToSave => 'لا توجد تغييرات للحفظ';

  @override
  String get shellViewTools => 'أدوات العرض';

  @override
  String get shellToolSelect => 'تحديد';

  @override
  String get shellToolHand => 'أداة اليد';

  @override
  String get shellToolMarqueeZoom => 'تكبير منطقة';

  @override
  String get shellZoomOut => 'تصغير';

  @override
  String get shellZoomIn => 'تكبير';

  @override
  String get shellZoom => 'مستوى التكبير';

  @override
  String get shellFit => 'ملاءمة';

  @override
  String get shellFitWidth => 'ملاءمة عرض الصفحة';

  @override
  String get shellFitPage => 'ملاءمة الصفحة';

  @override
  String get shellActualSize => 'الحجم الفعلي';

  @override
  String get shellPageLayout => 'تخطيط الصفحة';

  @override
  String get shellLayoutSingle => 'صفحة واحدة';

  @override
  String get shellLayoutContinuous => 'تمرير متواصل';

  @override
  String get shellLayoutTwoPage => 'صفحتان متجاورتان';

  @override
  String get shellLayoutBook => 'كتاب (صفحة الغلاف منفردة)';

  @override
  String get shellToolSplitView => 'عرض مقسّم';

  @override
  String get shellToolReadAloud => 'القراءة بصوت عالٍ';

  @override
  String get shellToolPresent => 'عرض تقديمي';

  @override
  String get shellDarkReadingMode => 'وضع القراءة الداكن';

  @override
  String get shellEditTools => 'أدوات التحرير';

  @override
  String get shellToolEditText => 'تحرير النص';

  @override
  String get shellToolAddText => 'إضافة نص';

  @override
  String get shellToolAddImage => 'إضافة صورة';

  @override
  String get shellToolLink => 'رابط';

  @override
  String get shellToolFindReplace => 'بحث واستبدال';

  @override
  String get shellToolPageMarks => 'علامات الصفحة';

  @override
  String get shellUndo => 'تراجع';

  @override
  String get shellRedo => 'إعادة';

  @override
  String get shellEditHistory => 'سجل التحرير';

  @override
  String get shellMarkEditedText => 'تمييز النص المعدّل';

  @override
  String get shellReviewEdits => 'مراجعة التعديلات';

  @override
  String get shellCommentTools => 'أدوات التعليق';

  @override
  String get shellAnnotationHighlight => 'تمييز';

  @override
  String get shellAnnotationUnderline => 'تسطير';

  @override
  String get shellAnnotationStrikethrough => 'شطب';

  @override
  String get shellAnnotationNote => 'ملاحظة';

  @override
  String get shellAnnotationText => 'نص';

  @override
  String get shellAnnotationCallout => 'وسيلة شرح';

  @override
  String get shellAnnotationDraw => 'رسم';

  @override
  String get shellAnnotationShapes => 'أشكال';

  @override
  String get shellAnnotationStamp => 'ختم';

  @override
  String get shellToolMeasure => 'قياس';

  @override
  String get shellColor => 'اللون';

  @override
  String get shellColorYellow => 'أصفر';

  @override
  String get shellColorGreen => 'أخضر';

  @override
  String get shellColorBlue => 'أزرق';

  @override
  String get shellColorPink => 'وردي';

  @override
  String get shellColorOrange => 'برتقالي';

  @override
  String get shellColorRed => 'أحمر';

  @override
  String get shellColorBlack => 'أسود';

  @override
  String get shellShowComments => 'إظهار التعليقات';

  @override
  String get shellFillSignTools => 'أدوات التعبئة والتوقيع';

  @override
  String get shellToolFillFields => 'تعبئة الحقول';

  @override
  String get shellToolCheckmark => 'علامة اختيار';

  @override
  String get shellToolDate => 'التاريخ';

  @override
  String get shellToolSign => 'توقيع';

  @override
  String get shellToolInitials => 'الأحرف الأولى';

  @override
  String get shellToolDigitalSignature => 'توقيع رقمي';

  @override
  String get shellToolEimza => 'e-imza';

  @override
  String get shellToolPrepareForm => 'إعداد نموذج';

  @override
  String get shellOrganizeTools => 'أدوات التنظيم';

  @override
  String get shellToolInsert => 'إدراج';

  @override
  String get shellToolRotateLeft => 'تدوير لليسار';

  @override
  String get shellToolRotateRight => 'تدوير لليمين';

  @override
  String get shellToolDuplicate => 'تكرار';

  @override
  String get shellToolExtract => 'استخراج';

  @override
  String get shellToolReplace => 'استبدال';

  @override
  String get shellToolDelete => 'حذف';

  @override
  String get shellToolSplit => 'تقسيم';

  @override
  String get shellToolCombineFiles => 'دمج الملفات';

  @override
  String get shellToolCrop => 'اقتصاص';

  @override
  String get shellToolPageLabels => 'تسميات الصفحات';

  @override
  String get shellOrganizeHint =>
      'اسحب الصفحات لإعادة ترتيبها. انقر بزر الماوس الأيمن للمزيد.';

  @override
  String get shellConvertTools => 'أدوات التحويل';

  @override
  String get shellConvertWord => 'Word';

  @override
  String get shellConvertExcel => 'Excel';

  @override
  String get shellConvertPowerPoint => 'PowerPoint';

  @override
  String get shellConvertImage => 'صورة';

  @override
  String get shellConvertHtml => 'HTML';

  @override
  String get shellConvertText => 'نص';

  @override
  String get shellConvertMarkdown => 'Markdown';

  @override
  String get shellToolCreatePdf => 'إنشاء PDF';

  @override
  String get shellToolScan => 'مسح';

  @override
  String get shellToolRecognizeText => 'التعرّف على النص (OCR)';

  @override
  String get shellProtectTools => 'أدوات الحماية';

  @override
  String get shellToolRedact => 'حجب';

  @override
  String get shellToolFindRedact => 'بحث وحجب';

  @override
  String get shellToolPassword => 'كلمة المرور';

  @override
  String get shellToolRemoveHidden => 'إزالة المعلومات المخفية';

  @override
  String get shellToolSecurityReport => 'تقرير الأمان';

  @override
  String get shellApplyRedactions => 'تطبيق الحجب';

  @override
  String get shellToolCompress => 'ضغط';

  @override
  String get shellToolCompare => 'مقارنة';

  @override
  String get shellToolAccessibility => 'إمكانية الوصول';

  @override
  String get shellToolPdfA => 'PDF/A والفحص المسبق';

  @override
  String get shellToolBatch => 'إجراءات مجمّعة';

  @override
  String get shellToolPrint => 'طباعة';

  @override
  String get shellToolVersionHistory => 'سجل الإصدارات';

  @override
  String get fieldContextMenu => 'حقل نص';

  @override
  String get fieldCut => 'قص';

  @override
  String get fieldCopy => 'نسخ';

  @override
  String get fieldPaste => 'لصق';

  @override
  String get fieldSelectAll => 'تحديد الكل';

  @override
  String get shellResizeSidebar => 'تغيير حجم الشريط الجانبي';

  @override
  String get shellResizePanel => 'تغيير حجم اللوحة';

  @override
  String get shellSidebar => 'الشريط الجانبي';

  @override
  String get shellSidebarPages => 'الصفحات';

  @override
  String get shellSidebarOutline => 'الإشارات المرجعية';

  @override
  String get shellSidebarAttachments => 'المرفقات';

  @override
  String get shellSidebarLayers => 'الطبقات';

  @override
  String get shellSidebarSignatures => 'التوقيعات';

  @override
  String get shellSidebarSearch => 'نتائج البحث';

  @override
  String get shellPageBadgesLegend => 'معنى شارات الصفحات';

  @override
  String get shellAddBookmark => 'إضافة إشارة مرجعية';

  @override
  String get shellMore => 'المزيد';

  @override
  String get shellMoreTools => 'مزيد من الأدوات';

  @override
  String shellReviewEditsCount(String count) {
    return 'مراجعة التعديلات ($count)';
  }

  @override
  String get shellWindowTooNarrow => 'وسّع النافذة لعرض هذه اللوحة';

  @override
  String get shellAttachFile => 'إرفاق ملف';

  @override
  String get shellPanelDocument => 'المستند';

  @override
  String get shellCanvas => 'صفحات المستند';

  @override
  String get shellPreviousPage => 'الصفحة السابقة';

  @override
  String get shellNextPage => 'الصفحة التالية';

  @override
  String shellPageOf(String page, String count) {
    return 'الصفحة $page من $count';
  }

  @override
  String shellSavedOnDevice(String time) {
    return 'حُفظ على هذا الجهاز · $time';
  }

  @override
  String get shellSaving => 'جارٍ الحفظ…';

  @override
  String get shellSaveError => 'تعذّر الحفظ';

  @override
  String get shellReadOnly => 'للقراءة فقط';

  @override
  String get appName => 'Ferman';

  @override
  String get availableInFutureVersion => 'متاح في إصدار قادم';

  @override
  String get windowMinimize => 'تصغير';

  @override
  String get windowMaximize => 'تكبير';

  @override
  String get windowRestore => 'استعادة';

  @override
  String get windowClose => 'إغلاق';

  @override
  String get languageAppLanguage => 'لغة التطبيق';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get languageNotTranslated => 'لم تُترجم بعد';

  @override
  String languageOptionNotTranslated(String language) {
    return '$language · لم تُترجم بعد';
  }

  @override
  String get languageNameEnglish => 'الإنجليزية';

  @override
  String get languageNameTurkish => 'التركية';

  @override
  String get languageNameArabic => 'العربية';

  @override
  String get onboardingLanguageTitle => 'اختر لغة';

  @override
  String onboardingLanguageSubtitleSystem(String language) {
    return 'اختيرت $language لأنها لغة نظامك. يمكنك تغييرها في أي وقت من الإعدادات › اللغة والمنطقة.';
  }

  @override
  String get onboardingLanguageSubtitle =>
      'يمكنك تغييرها في أي وقت من الإعدادات › اللغة والمنطقة.';

  @override
  String get onboardingLanguageSearchPlaceholder =>
      'ابحث عن لغة · Search languages · Dil ara · Sprache suchen';

  @override
  String get onboardingLanguageSearchLabel => 'ابحث عن لغة';

  @override
  String onboardingLanguageNoMatch(String query) {
    return 'لا توجد لغة تطابق «$query».';
  }

  @override
  String get onboardingLanguageNoMatchBody =>
      'ابحث باسم اللغة بلغتها أو باسمها الإنجليزي أو برمزها.';

  @override
  String get onboardingLanguageMissing => 'لم تجد لغتك؟';

  @override
  String get onboardingLanguageHelpTranslate => 'ساعد في ترجمة Ferman';

  @override
  String get onboardingContinue => 'متابعة';

  @override
  String onboardingStep(String step, String count) {
    return '$step من $count';
  }

  @override
  String onboardingStepLabel(String step, String count) {
    return 'الخطوة $step من $count';
  }

  @override
  String get onboardingSkip => 'تخطّي';

  @override
  String get onboardingBack => 'رجوع';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingStartUsing => 'بدء استخدام Ferman';

  @override
  String get onboardingPrivacyTitle => 'يبقى كل شيء على جهازك';

  @override
  String get onboardingPrivacyBody =>
      'على هذا الجهاز، يفتح Ferman المستندات ويحرّرها ويوقّعها ويتعرّف على نصوصها. لا حاجة إلى إنشاء حساب أو رفع أي شيء.';

  @override
  String get onboardingPrivacyFilesTitle => 'تبقى الملفات على هذا الجهاز';

  @override
  String get onboardingPrivacyFilesBody =>
      'يقرأ Ferman الملفات ويحفظها في أماكنها. لا يُرفع أي شيء.';

  @override
  String get onboardingPrivacyOfflineTitle => 'يعمل دون اتصال';

  @override
  String get onboardingPrivacyOfflineBody =>
      'لا يحتاج التحرير والتعرّف على النص (OCR) والتوقيع والتحويل إلى اتصال بالإنترنت.';

  @override
  String get onboardingPrivacyAccountTitle => 'بلا حساب';

  @override
  String get onboardingPrivacyAccountBody =>
      'لا حاجة إلى التسجيل ولا إلى تسجيل الدخول.';

  @override
  String get onboardingPrivacyTelemetryTitle => 'بلا قياس عن بُعد';

  @override
  String get onboardingPrivacyTelemetryBody =>
      'لا يجمع Ferman بيانات الاستخدام ولا تقارير الأعطال.';

  @override
  String get onboardingPrivacyUpdatesTitle => 'فحص اختياري واحد للتحديثات';

  @override
  String get onboardingPrivacyUpdatesBody =>
      'مرة واحدة يوميًا، ولا يُرسَل سوى رقم الإصدار ونظام التشغيل. يمكنك إيقافه.';

  @override
  String get onboardingPrivacyPacksTitle => 'حزم لغات OCR';

  @override
  String get onboardingPrivacyPacksBody =>
      'لا تُنزَّل إلا عندما تختار ذلك. معطّلة حتى تستخدمها.';

  @override
  String get onboardingPrivacyAiTitle => 'المساعد الذكي';

  @override
  String get onboardingPrivacyAiBody =>
      'يعمل على هذا الجهاز أو يستخدم مفتاح API الخاص بك. معطّل حتى تستخدمه.';

  @override
  String get onboardingPrivacyTimestampsTitle => 'الطوابع الزمنية للتوقيعات';

  @override
  String get onboardingPrivacyTimestampsBody =>
      'يتصل بخادم الطوابع الزمنية الذي اخترته عند التوقيع. معطّل حتى تستخدمه.';

  @override
  String get onboardingPrivacySettingsLink =>
      'عرض كل الاتصالات في الإعدادات › الخصوصية';

  @override
  String get onboardingFreeTitle => 'مجاني إلى الأبد، ولا شيء مقفل';

  @override
  String get onboardingFreeBody =>
      'كل الميزات مضمّنة، دون فترة تجريبية أو اشتراك أو باقة مدفوعة. Ferman مفتوح المصدر، لذا يمكن لأي شخص قراءة شيفرته وفحصها وتحسينها.';

  @override
  String get onboardingFreeLicence => 'الترخيص: Apache-2.0';

  @override
  String get onboardingFreeSourceCode => 'الشيفرة المصدرية';

  @override
  String get onboardingFreeSupport => 'دعم المشروع';

  @override
  String get onboardingFeatureEditing => 'تحرير النصوص والصور';

  @override
  String get onboardingFeatureOcr => 'التعرّف على النص (OCR)';

  @override
  String get onboardingFeatureFillSign => 'تعبئة النماذج وتوقيعها';

  @override
  String get onboardingFeatureSignatures => 'e-imza والتوقيعات الرقمية';

  @override
  String get onboardingFeatureRedaction => 'حجب المحتوى';

  @override
  String get onboardingFeatureConvert => 'التحويل من Office وإليه';

  @override
  String get onboardingFeatureCompare => 'مقارنة المستندات';

  @override
  String get onboardingFeatureBatch => 'إجراءات مجمّعة';

  @override
  String get onboardingFeatureAccessibility => 'مدقّق إمكانية الوصول';

  @override
  String onboardingFeatureLanguages(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted لغة للواجهة',
      many: '$formatted لغة للواجهة',
      few: '$formatted لغات للواجهة',
      two: 'لغتان للواجهة',
      one: 'لغة واحدة للواجهة',
      zero: '$formatted لغة للواجهة',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFeatureIncluded => 'مضمّنة';

  @override
  String get startOpenFile => 'فتح ملف…';

  @override
  String get startOpenFileDescription => 'ملفات PDF';

  @override
  String get startCreatePdf => 'إنشاء PDF';

  @override
  String get startCreatePdfDescription => 'من صفحة فارغة أو ملفات أو الحافظة';

  @override
  String get startCombineFiles => 'دمج الملفات';

  @override
  String get startCombineFilesDescription => 'دمج عدة ملفات في ملف PDF واحد';

  @override
  String get startScanToPdf => 'مسح ضوئي إلى PDF';

  @override
  String get startScanToPdfDescription => 'من ماسح ضوئي أو كاميرا الهاتف';

  @override
  String get startQuickTools => 'أدوات سريعة';

  @override
  String get startToolCompress => 'ضغط';

  @override
  String get startToolConvert => 'تحويل';

  @override
  String get startToolSign => 'توقيع';

  @override
  String get startToolOcr => 'التعرّف على النص (OCR)';

  @override
  String get startToolProtect => 'حماية';

  @override
  String get startToolCompare => 'مقارنة';

  @override
  String get startDropTitle => 'أفلت ملف PDF هنا';

  @override
  String get startDropSubtitle => 'أو افتح ملفًا من جهازك.';

  @override
  String get startDropFootnote => 'تبقى الملفات على هذا الجهاز.';

  @override
  String get startOpenPdf => 'فتح ملف PDF';

  @override
  String get startNewBlankPdf => 'ملف PDF فارغ جديد';

  @override
  String get startEngineUnavailableTitle =>
      'يتعذّر على Ferman فتح ملفات PDF حاليًا.';

  @override
  String get startEngineUnavailableMessage =>
      'أحد أجزاء Ferman مفقود أو لا يطابق هذا الإصدار. تُصلح إعادة تثبيت Ferman ذلك.';

  @override
  String get startCopyTechnicalDetails => 'نسخ التفاصيل التقنية';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSearch => 'البحث في الإعدادات';

  @override
  String get settingsClose => 'إغلاق الإعدادات';

  @override
  String get settingsSaveFailedTitle => 'تعذّر حفظ إعداداتك.';

  @override
  String get settingsSaveFailedMessage => 'يسري هذا التغيير حتى تُغلق Ferman.';

  @override
  String get settingsSaveFailedDismiss => 'تجاهل';

  @override
  String get settingsPaneGeneral => 'عام';

  @override
  String get settingsPaneLanguage => 'اللغة والمنطقة';

  @override
  String get settingsPaneEditing => 'التحرير';

  @override
  String get settingsPaneFonts => 'الخطوط';

  @override
  String get settingsPaneSignatures => 'التوقيعات والشهادات';

  @override
  String get settingsPaneOcr => 'التعرّف على النص (OCR)';

  @override
  String get settingsPaneAi => 'المساعد الذكي';

  @override
  String get settingsPanePrivacy => 'الخصوصية';

  @override
  String get settingsPaneUpdates => 'التحديثات';

  @override
  String get settingsPaneShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get settingsPaneAdvanced => 'متقدّم';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsThemeSystem => 'حسب النظام';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsPageTheme => 'صفحات PDF في المظهر الداكن';

  @override
  String get settingsPagePaper => 'أبيض كالورق';

  @override
  String get settingsPagePaperDescription => 'تظهر الصفحات تمامًا كما تُطبع.';

  @override
  String get settingsPageDimmed => 'خافت';

  @override
  String get settingsPageDimmedDescription =>
      'أغمق قليلًا مع مسحة من لون السيبيا. لا تُعكس الألوان.';

  @override
  String get settingsPageDark => 'وضع القراءة الداكن';

  @override
  String get settingsPageDarkDescription =>
      'نص فاتح على صفحات داكنة. تحتفظ الصور بألوانها. لا يُطبَّق عند الطباعة.';

  @override
  String get settingsPageLayout => 'تخطيط الصفحة للمستندات الجديدة';

  @override
  String get settingsPageLayoutScroll => 'تمرير متواصل';

  @override
  String get settingsPageLayoutSingle => 'صفحة واحدة';

  @override
  String get settingsPageLayoutSpread => 'صفحتان متجاورتان';

  @override
  String get settingsZoom => 'مستوى التكبير';

  @override
  String get settingsZoomFitWidth => 'ملاءمة عرض الصفحة';

  @override
  String get settingsZoomFitPage => 'ملاءمة الصفحة';

  @override
  String get settingsReopen => 'إعادة فتح مستندات الجلسة الأخيرة';

  @override
  String get settingsDefaultApp =>
      'يمكن أن يكون Ferman التطبيق الذي يُفتح عند النقر المزدوج على ملف PDF.';

  @override
  String get settingsDefaultAppWindows =>
      'يمكن أن يكون Ferman التطبيق الذي يُفتح عند النقر المزدوج على ملف PDF. يتيح لك Windows اختياره من الإعدادات › التطبيقات الافتراضية.';

  @override
  String get settingsMakeDefault => 'تعيين Ferman كتطبيق افتراضي…';

  @override
  String get settingsAppLanguageHint => 'يتغيّر Ferman فورًا دون إعادة تشغيل.';

  @override
  String get settingsDocumentLanguages => 'لغات المستندات';

  @override
  String get settingsDocumentLanguagesHint =>
      'تُستخدم للتعرّف على النص والتدقيق الإملائي والوصل بشرطة عندما لا يحدّد المستند لغته.';

  @override
  String get settingsAddDocumentLanguage => 'إضافة';

  @override
  String get settingsPrivacyStatement => 'لا يجمع Ferman أي شيء.';

  @override
  String get settingsPrivacyStatementBody =>
      'لا بيانات استخدام، ولا تقارير أعطال، ولا محتوى مستندات، ولا حساب. تبقى الملفات على هذا الجهاز. هذه هي الحالات الوحيدة التي يتصل فيها Ferman بالإنترنت، ويمكن إيقاف كلٍّ منها:';

  @override
  String get settingsNetUpdates => 'التحقق من وجود تحديثات';

  @override
  String get settingsNetUpdatesDescription =>
      'مرة واحدة يوميًا؛ يُرسل رقم الإصدار ونظام التشغيل فقط.';

  @override
  String get settingsNetSignatureChecks => 'التحقق من التوقيعات';

  @override
  String get settingsNetSignatureChecksDescription =>
      'يسأل مزوّد الشهادة عمّا إذا كانت الشهادة قد أُبطلت، عند التوقيع أو فتح ملف موقّع.';

  @override
  String get settingsNetTimestamps => 'الطوابع الزمنية';

  @override
  String get settingsNetTimestampsDescription =>
      'يتصل بخادم الطوابع الزمنية الذي اخترته عند التوقيع.';

  @override
  String get settingsNetDownloads => 'التنزيلات التي تبدؤها';

  @override
  String get settingsNetDownloadsDescription =>
      'حزم لغات OCR ونموذج المساعد الذكي.';

  @override
  String get settingsNetAiProvider => 'مزوّد الذكاء الاصطناعي الخاص بك';

  @override
  String get settingsNetAiProviderDescription =>
      'فقط إذا أضفت مفتاح API الخاص بك. معطّل.';

  @override
  String get settingsNetworkActivity => 'عرض نشاط الشبكة…';

  @override
  String get regionFormats => 'تنسيقات المنطقة';

  @override
  String get regionPaperSize => 'حجم الورق';

  @override
  String get regionPaperA4 => 'A4';

  @override
  String get regionPaperLetter => 'Letter';

  @override
  String get regionUnits => 'الوحدات';

  @override
  String get regionFirstDay => 'أول أيام الأسبوع';

  @override
  String get regionMonday => 'الاثنين';

  @override
  String get regionSunday => 'الأحد';

  @override
  String get regionSaturday => 'السبت';

  @override
  String get regionFriday => 'الجمعة';

  @override
  String get regionExamples => 'أمثلة';

  @override
  String get regionExampleDate => 'التاريخ';

  @override
  String get regionExampleTime => 'الوقت';

  @override
  String get regionExampleNumber => 'الرقم';

  @override
  String get regionExampleFontSize => 'حجم الخط';

  @override
  String viewerPageFailed(String page) {
    return 'تعذّر على Ferman عرض الصفحة $page.';
  }

  @override
  String get viewerPageFailedReason =>
      'تعذّرت قراءة عنصر في هذه الصفحة. يعمل باقي المستند كالمعتاد.';

  @override
  String get viewerTryAgain => 'إعادة المحاولة';

  @override
  String viewerMarqueeZoom(String zoom) {
    return 'أفلِت للتكبير إلى $zoom';
  }

  @override
  String editHoverTip(String block) {
    return 'انقر للتحرير · $block';
  }

  @override
  String get editNotEditableTitle => 'لا يمكن تحرير هذا النص';

  @override
  String get editTipImageOnly =>
      'لا يوجد نص في هذه الصفحة بعد · تعرّف على النص لتحريره';

  @override
  String get editBodyImageOnly =>
      'هذه الصفحة صورة، مثل مستند ممسوح ضوئيًا. تعرّف على نصها لتحريرها.';

  @override
  String get editTipOutlinedText => 'هذا النص مرسوم كأشكال، فلا يمكن تحريره';

  @override
  String get editBodyOutlinedText =>
      'هذا النص مرسوم كأشكال متجهة لا كحروف. لا يستطيع Ferman تغييره دون إعادة رسمه.';

  @override
  String get editTipUnknownText => 'لا يستطيع Ferman قراءة حروف هذا النص';

  @override
  String get editBodyUnknownText =>
      'لا يحدد خطه الحروف التي تمثلها أشكاله، لذا لا يستطيع Ferman تغييره بأمان.';

  @override
  String get editTipInvisibleText => 'هذا النص غير مرئي';

  @override
  String get editBodyInvisibleText =>
      'إنه نص مخفي، مثل نص متعرَّف عليه فوق مستند ممسوح ضوئيًا. لا يحرره Ferman.';

  @override
  String get editTipRestricted => 'أذونات المؤلف لا تسمح بالتحرير';

  @override
  String get editBodyRestricted =>
      'افتح قفل المستند بكلمة مرور المالك لتحريره.';

  @override
  String get editTipReadOnly => 'هذا المستند للقراءة فقط';

  @override
  String get editBodyReadOnly =>
      'فتح Ferman هذا المستند للعرض فقط، لذا لا يمكن تغيير نصه.';

  @override
  String get editTipDamaged => 'تم إصلاح هذا المستند، لذا لا يمكن تحريره';

  @override
  String get editBodyDamaged =>
      'وجد Ferman مشكلات في هذا الملف وفتحه للعرض فقط. احفظ نسخة مُصلَحة لتحريره.';

  @override
  String get editTipSignature => 'هذا النص جزء من توقيع';

  @override
  String get editBodySignature => 'لا يحرر Ferman التوقيعات أبدًا.';

  @override
  String get editTipAnnotation => 'هذا النص يتبع تعليقًا أو حقل نموذج';

  @override
  String get editBodyAnnotation => 'غيّره في وضع التعليق أو التعبئة والتوقيع.';

  @override
  String get editTipTooComplex => 'لا يستطيع Ferman تغيير هذا النص بأمان';

  @override
  String get editBodyLimits =>
      'هذه الصفحة كبيرة أو معقدة جدًا ليعيد Ferman كتابتها بأمان.';

  @override
  String get editBodySplit =>
      'تعليمات رسمه مقسمة بين جزأين من الصفحة، لذا لا يستطيع Ferman إعادة كتابته بأمان.';

  @override
  String get editBodySkewed =>
      'هذا النص مائل، لذا لا يستطيع Ferman إعادة كتابته بأمان.';

  @override
  String get viewerTextMenu => 'النص';

  @override
  String get viewerPageNumber => 'رقم الصفحة';

  @override
  String sidebarPage(String page) {
    return 'الصفحة $page';
  }

  @override
  String get sidebarNoBookmarks => 'لا توجد إشارات مرجعية';

  @override
  String get sidebarNoBookmarksBody =>
      'لا يحتوي هذا المستند على إشارات مرجعية. أضف إشارة لتعليم موضع تريد العودة إليه.';

  @override
  String get sidebarNoAttachments => 'لا توجد مرفقات';

  @override
  String get sidebarNoAttachmentsBody =>
      'تظهر هنا الملفات المضمّنة في ملف PDF هذا.';

  @override
  String get sidebarNoLayers => 'لا توجد طبقات';

  @override
  String get sidebarNoLayersBody =>
      'لا يحتوي هذا المستند على طبقات يمكن إظهارها أو إخفاؤها.';

  @override
  String get sidebarNoSignatures => 'لا توجد توقيعات';

  @override
  String get sidebarNoSignaturesBody =>
      'هذا المستند غير موقّع ولا يحتوي على حقول توقيع.';

  @override
  String get sidebarAttachmentsNote =>
      'تُفتح المرفقات في تطبيقاتها الخاصة. لا يشغّل Ferman الملفات المضمّنة.';

  @override
  String get sidebarSaveAttachment => 'حفظ المرفق باسم…';

  @override
  String get sidebarLayersNote =>
      'تُطبع الطبقات المخفية ما لم توقف «طباعة الطبقات المخفية» في نافذة الطباعة.';

  @override
  String get sidebarHideLayer => 'إخفاء الطبقة';

  @override
  String get sidebarShowLayer => 'إظهار الطبقة';

  @override
  String get sidebarLayerLocked => 'مقفلة';

  @override
  String get sidebarSignatureCheckingLater =>
      'التحقق من التوقيعات متاح في إصدار قادم.';

  @override
  String get sidebarEmptySignatureField => 'حقل توقيع فارغ';

  @override
  String get findRegion => 'بحث واستبدال';

  @override
  String get findField => 'بحث';

  @override
  String get findReplaceWith => 'استبدال بـ';

  @override
  String get findMatchCase => 'مطابقة حالة الأحرف';

  @override
  String get findWholeWords => 'كلمات كاملة';

  @override
  String get findRegex => 'تعبير نمطي';

  @override
  String get findShowReplace => 'إظهار الاستبدال';

  @override
  String get findHideReplace => 'إخفاء الاستبدال';

  @override
  String get findPrevious => 'التطابق السابق';

  @override
  String get findNext => 'التطابق التالي';

  @override
  String get findReplaceAll => 'استبدال الكل';

  @override
  String get findNoResults => 'لا نتائج';

  @override
  String get findOptions => 'خيارات البحث';

  @override
  String get findMatch => 'المطابقة';

  @override
  String get findIgnoreAccents =>
      'تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة';

  @override
  String get findIgnoreAccentsBody =>
      '«i» تجد İ وı وî؛ و«c» تجد ç؛ و«kira» تجد KİRA. مفعّل افتراضيًا.';

  @override
  String get findLookIn => 'البحث في';

  @override
  String get findPageText => 'نص الصفحة';

  @override
  String get findComments => 'التعليقات';

  @override
  String get findFormFields => 'حقول النماذج';

  @override
  String get findBookmarks => 'الإشارات المرجعية';

  @override
  String get findSearchingBody => 'تظهر النتائج فور العثور عليها.';

  @override
  String get findCancel => 'إلغاء';

  @override
  String get findNoneAction => 'البحث في التعليقات والحقول أيضًا';

  @override
  String findCount(String current, String total) {
    return '$current من $total';
  }

  @override
  String get statusSearching => 'جارٍ البحث';

  @override
  String findSearching(String page, String pages) {
    return 'جارٍ البحث · الصفحة $page من $pages';
  }

  @override
  String findNoneTitle(String query) {
    return 'لا نتائج لـ«$query»';
  }

  @override
  String findNoneBody(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الصفحات الـ$pages كلها',
      two: 'الصفحتين كلتيهما',
      one: 'الصفحة الوحيدة',
    );
    return 'بحث Ferman في $_temp0، مع تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة. لم يُبحث في التعليقات وحقول النماذج.';
  }

  @override
  String findNoneBodyExact(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الصفحات الـ$pages كلها',
      two: 'الصفحتين كلتيهما',
      one: 'الصفحة الوحيدة',
    );
    return 'بحث Ferman في $_temp0. لم يُبحث في التعليقات وحقول النماذج.';
  }

  @override
  String get sidebarSearchField => 'البحث في المستند';

  @override
  String sidebarSearchBookmark(String title) {
    return 'إشارة مرجعية: $title';
  }

  @override
  String get sidebarSearchNoTextTitle => 'لا يوجد نص للبحث فيه';

  @override
  String get sidebarSearchNoTextBody =>
      'هذه الصفحات صور ممسوحة ضوئيًا. التعرّف على النص يجعلها قابلة للبحث.';

  @override
  String sidebarSearchSummary(
    int matches,
    String matchesText,
    int pages,
    String pagesText,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matchesText تطابقًا',
      few: '$matchesText تطابقات',
      two: 'تطابقان',
      one: 'تطابق واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pagesText صفحة',
      few: '$pagesText صفحات',
      two: 'صفحتين',
      one: 'صفحة واحدة',
    );
    return '$_temp0 في $_temp1';
  }

  @override
  String get openPdfFilter => 'مستندات PDF';

  @override
  String openFailedTitle(String name) {
    return 'يتعذّر على Ferman فتح «$name»';
  }

  @override
  String get openFailedDismiss => 'تجاهل';

  @override
  String get shellSavedOnDeviceUndated => 'حُفظ على هذا الجهاز';

  @override
  String get shellMoreDocumentsMenu => 'مستندات مفتوحة أخرى';

  @override
  String shellMoreDocumentsHeading(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText مستند آخر',
      many: '$countText مستندًا آخر',
      few: '$countText مستندات أخرى',
      two: 'مستندان آخران',
      one: 'مستند واحد آخر',
    );
    return '$_temp0';
  }

  @override
  String shellMoreDocumentsUnsaved(String name) {
    return '$name · غير محفوظ';
  }

  @override
  String get shellShowAllDocuments => 'عرض كل المستندات المفتوحة';

  @override
  String get shellCloseOtherDocuments => 'إغلاق المستندات الأخرى…';

  @override
  String get dropOverlayTitle => 'أفلت لفتح الملفات';

  @override
  String get dropOverlayHint => 'مرّر فوق أحد الخيارين ثم أفلت.';

  @override
  String get dropOverlayTabs => 'فتح في علامات تبويب';

  @override
  String get dropOverlayTabsDescription => 'يُفتح كل ملف على حدة.';

  @override
  String get dropOverlayCombine => 'دمج في ملف PDF واحد';

  @override
  String get startDropStripTitle => 'أفلت الملفات في أي مكان في هذه النافذة';

  @override
  String get startDropStripSubtitle => 'تُفتح ملفات PDF في علامات تبويب.';

  @override
  String get startPinned => 'المثبّتة';

  @override
  String get startPin => 'تثبيت';

  @override
  String get startUnpin => 'إلغاء التثبيت';

  @override
  String get startRecent => 'الأخيرة';

  @override
  String get startSearchRecent => 'البحث في الملفات الأخيرة';

  @override
  String get startSort => 'الترتيب';

  @override
  String get startSortOpened => 'آخر فتح';

  @override
  String get startSortName => 'الاسم';

  @override
  String get startSortLocation => 'الموقع';

  @override
  String get startView => 'العرض';

  @override
  String get startViewGrid => 'شبكة';

  @override
  String get startViewList => 'قائمة';

  @override
  String get startColumnPages => 'الصفحات';

  @override
  String get startColumnOpened => 'آخر فتح';

  @override
  String get startRecentFooter => 'تُعرض الملفات الأخيرة على هذا الجهاز فقط.';

  @override
  String get startClearList => 'مسح القائمة';

  @override
  String startNoRecentMatch(String query) {
    return 'لا يطابق أي ملف حديث «$query».';
  }

  @override
  String startPages(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$pages صفحة',
    );
    return '$_temp0';
  }

  @override
  String startOpenedToday(String time) {
    return 'اليوم $time';
  }

  @override
  String startOpenedYesterday(String time) {
    return 'أمس $time';
  }

  @override
  String get startBadgeSigned => 'موقّع';

  @override
  String get startBadgeForm => 'نموذج';

  @override
  String get startBadgeScanned => 'ممسوح ضوئيًا';

  @override
  String startMissingTitle(String name) {
    return 'تعذّر العثور على «$name»';
  }

  @override
  String startMissingDescription(String folder) {
    return 'نُقل الملف أو أُعيدت تسميته أو حُذف بعد آخر مرة فتحته فيها. كان في $folder.';
  }

  @override
  String get startMissingRemove => 'إزالة من القائمة';

  @override
  String get startMissingLocate => 'تحديد الموقع…';

  @override
  String get startMissingClose => 'إغلاق';

  @override
  String get errorInternal =>
      'حدث خطأ داخل Ferman. انسخ التفاصيل التقنية للإبلاغ عنه.';

  @override
  String get errorFileNotFound =>
      'لم يعد الملف موجودًا. ربما نُقل أو أُعيدت تسميته أو حُذف.';

  @override
  String get errorFilePermissionDenied =>
      'لا يسمح هذا الجهاز لـ Ferman بقراءة الملف. تحقّق من صلاحيات فتحه، أو انسخه إلى أحد مجلداتك.';

  @override
  String get errorFileRead =>
      'تعذّر على Ferman قراءة الملف من القرص. تأكّد من أن القرص ما زال متصلًا، ثم أعد المحاولة.';

  @override
  String errorNotPdf(String name) {
    return '«$name» ليس ملف PDF. يفتح Ferman ملفات PDF.';
  }

  @override
  String get errorPasswordRequired => 'ملف PDF هذا محمي بكلمة مرور';

  @override
  String get errorWrongPassword =>
      'لم تنجح كلمة المرور هذه. تحقّق من مفتاح Caps Lock ومن تخطيط لوحة المفاتيح: في لوحة المفاتيح التركية الحرفان ı وi مفتاحان مختلفان.';

  @override
  String get errorDamaged =>
      'الملف تالف ولا يستطيع Ferman إصلاحه. حاول الحصول على الملف مرة أخرى.';

  @override
  String get errorDamagedTruncated =>
      'ينتهي الملف قبل نهايته والباقي مفقود. ربما انقطع أثناء التنزيل أو النسخ. حاول الحصول على الملف مرة أخرى.';

  @override
  String get errorDamagedEmpty =>
      'يبدأ الملف كملف PDF، لكن لا شيء بعد ذلك قابل للقراءة. حاول الحصول على الملف مرة أخرى.';

  @override
  String get errorUnsupported =>
      'يستخدم شيئًا لا يدعمه Ferman بعد، مثل التشفير بشهادة.';

  @override
  String get errorTooComplex =>
      'هذا الملف معقّد جدًا لفتحه ضمن حدود الأمان في Ferman. مستنداتك الأخرى مفتوحة ولم تتغيّر.';

  @override
  String get errorOutOfMemory =>
      'نفدت ذاكرة الجهاز أثناء فتحه. مستنداتك الأخرى مفتوحة ولم تتغيّر.';

  @override
  String openClosedTitle(String name) {
    return 'أُغلق «$name»';
  }

  @override
  String get openTryAgain => 'إعادة المحاولة';

  @override
  String get openNotPdfTitle => 'هذا الملف ليس ملف PDF.';

  @override
  String get openAnotherFile => 'فتح ملف آخر…';

  @override
  String get openShowInFinder => 'إظهار في Finder';

  @override
  String get openShowInExplorer => 'إظهار في مستكشف الملفات';

  @override
  String get openShowInFolder => 'إظهار في المجلد';

  @override
  String get openConvertToPdf => 'تحويل إلى PDF…';

  @override
  String unlockDescription(String name) {
    return 'أدخل كلمة مرور «$name». ينسى Ferman كلمة المرور عند إغلاق الملف.';
  }

  @override
  String get unlockPassword => 'كلمة المرور';

  @override
  String get unlockShowPassword => 'إظهار كلمة المرور';

  @override
  String get unlockCancel => 'إلغاء';

  @override
  String get unlockOpen => 'فتح';

  @override
  String get restrictedTitle => 'قيّد المؤلف هذا المستند.';

  @override
  String get restrictedBody =>
      'يمكنك قراءته وطباعته. التحرير والتعليقات وتعبئة النماذج معطّلة.';

  @override
  String get restrictedBodyOther => 'يمكنك قراءته. عطّل المؤلف بعض الإجراءات.';

  @override
  String get restrictedUnlock => 'فتح القفل بكلمة مرور المالك…';

  @override
  String get ownerUnlockTitle => 'فتح القفل بكلمة مرور المالك';

  @override
  String ownerUnlockDescription(String name) {
    return 'أدخل كلمة مرور المالك لـ«$name». ينسى Ferman كلمة المرور عند إغلاق الملف.';
  }

  @override
  String get ownerUnlockPassword => 'كلمة مرور المالك';

  @override
  String get ownerUnlockAction => 'فتح القفل';

  @override
  String scriptsTitle(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يحتوي هذا المستند على $countText برنامج نصي.',
      many: 'يحتوي هذا المستند على $countText برنامجًا نصيًا.',
      few: 'يحتوي هذا المستند على $countText برامج نصية.',
      two: 'يحتوي هذا المستند على برنامجين نصيين.',
      one: 'يحتوي هذا المستند على برنامج نصي واحد.',
    );
    return '$_temp0';
  }

  @override
  String get scriptsBody =>
      'لا يشغّل Ferman البرامج النصية أبدًا، وقد تشغّلها تطبيقات أخرى.';

  @override
  String get scriptsDismiss => 'إغلاق';

  @override
  String get repairedTitle => 'أصلح Ferman هذا الملف.';

  @override
  String repairedBody(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُصلحت $countText مشكلة في هذه النسخة.',
      many: 'أُصلحت $countText مشكلة في هذه النسخة.',
      few: 'أُصلحت $countText مشكلات في هذه النسخة.',
      two: 'أُصلحت مشكلتان في هذه النسخة.',
      one: 'أُصلحت مشكلة واحدة في هذه النسخة.',
      zero: 'أُصلحت مشكلات في هذه النسخة.',
    );
    return '$_temp0 يبقى الأصل كما هو حتى تحفظ.';
  }

  @override
  String get repairedDetails => 'التفاصيل';

  @override
  String get repairedSave => 'حفظ النسخة المُصلَحة…';

  @override
  String get repairDetailsTitle => 'ما الذي أصلحه Ferman';

  @override
  String get repairCopyDetails => 'نسخ التفاصيل';

  @override
  String get repairXrefTitle => 'كان جدول الإسناد الترافقي تالفًا';

  @override
  String repairXrefBody(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُعيد بناؤه من $countText كائن موجود في الملف.',
      many: 'أُعيد بناؤه من $countText كائنًا موجودًا في الملف.',
      few: 'أُعيد بناؤه من $countText كائنات موجودة في الملف.',
      two: 'أُعيد بناؤه من الكائنين الموجودين في الملف.',
      one: 'أُعيد بناؤه من الكائن الوحيد الموجود في الملف.',
    );
    return '$_temp0';
  }

  @override
  String repairPagesPresent(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الصفحات الـ$countText كلها موجودة.',
      many: 'الصفحات الـ$countText كلها موجودة.',
      few: 'الصفحات الـ$countText كلها موجودة.',
      two: 'الصفحتان موجودتان.',
      one: 'الصفحة موجودة.',
    );
    return '$_temp0';
  }

  @override
  String get repairTrailerTitle => 'كان مقطع الذيل (trailer) في الملف مفقودًا';

  @override
  String get repairTrailerBody => 'عثر Ferman على بداية المستند بين كائناته.';

  @override
  String repairStreamsTitle(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كان طول $countText تدفق خاطئًا',
      many: 'كان طول $countText تدفقًا خاطئًا',
      few: 'كان طول $countText تدفقات خاطئًا',
      two: 'كان طول تدفقين خاطئًا',
      one: 'كان طول تدفق واحد خاطئًا',
    );
    return '$_temp0';
  }

  @override
  String get repairStreamsBody => 'قرأ Ferman كل واحد منها حتى نهايته.';

  @override
  String repairUnreadableTitle(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّرت قراءة $countText كائن',
      many: 'تعذّرت قراءة $countText كائنًا',
      few: 'تعذّرت قراءة $countText كائنات',
      two: 'تعذّرت قراءة كائنين',
      one: 'تعذّرت قراءة كائن واحد',
    );
    return '$_temp0';
  }

  @override
  String get repairUnreadableBody =>
      'قد تكون الصفحات والميزات التي تستخدمها غير مكتملة.';

  @override
  String get xfaTitle => 'هذا نموذج XFA، ولا يستطيع Ferman عرضه.';

  @override
  String get xfaBody =>
      'XFA تنسيق متوقف من Adobe. افتحه في Adobe Acrobat Reader، أو اطلب من المرسل ملف PDF عاديًا.';

  @override
  String disagreeTitle(String name) {
    return 'فتح Ferman «$name» للقراءة فقط.';
  }

  @override
  String get disagreeBody =>
      'بعض أجزاء هذا الملف لا تتطابق مع بعضها، وقد يعني ذلك أنه تالف. يمكنك قراءته كالمعتاد.';

  @override
  String get propertiesFile => 'الملف';

  @override
  String get propertiesFonts => 'الخطوط في هذا المستند';

  @override
  String get propertiesSecurity => 'الأمان';

  @override
  String get propertiesPages => 'الصفحات';

  @override
  String get propertiesPageSize => 'حجم الصفحة';

  @override
  String get propertiesFileSize => 'حجم الملف';

  @override
  String get propertiesVersion => 'إصدار PDF';

  @override
  String propertiesVersionAcrobat(String version, String acrobat) {
    return '$version (Acrobat $acrobat.x)';
  }

  @override
  String get propertiesLocation => 'الموقع';

  @override
  String get propertiesCreated => 'تاريخ الإنشاء';

  @override
  String get propertiesModified => 'تاريخ التعديل';

  @override
  String get propertiesTitle => 'العنوان';

  @override
  String get propertiesAuthor => 'المؤلف';

  @override
  String get propertiesSubject => 'الموضوع';

  @override
  String get propertiesKeywords => 'الكلمات المفتاحية';

  @override
  String get propertiesTagged => 'PDF موسوم';

  @override
  String get propertiesFastWebView => 'عرض ويب سريع';

  @override
  String get propertiesMadeWith => 'أُنشئ باستخدام';

  @override
  String get propertiesYes => 'نعم';

  @override
  String get propertiesNo => 'لا';

  @override
  String get propertiesNone => 'لا يوجد';

  @override
  String get propertiesNoPassword => 'بلا كلمة مرور';

  @override
  String get propertiesOwnerPassword => 'كلمة مرور المالك';

  @override
  String propertiesSignatures(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText توقيع',
      many: '$countText توقيعًا',
      few: '$countText توقيعات',
      two: 'توقيعان',
      one: 'توقيع واحد',
    );
    return '$_temp0';
  }

  @override
  String propertiesSignatureOnPage(String page) {
    return 'توقيع واحد، الصفحة $page';
  }

  @override
  String get propertiesEmbedded => 'مضمَّن';

  @override
  String get propertiesPartial => 'جزئي';

  @override
  String get propertiesPartialNote =>
      'مجموعة فرعية: الأحرف الموجودة في الملف فقط.';

  @override
  String get propertiesSubset => 'مجموعة فرعية';

  @override
  String get propertiesSubsetNote => 'الأحرف المستخدمة فقط.';

  @override
  String get propertiesNotEmbedded => 'غير مضمَّن';

  @override
  String get propertiesFontType1 => 'Type 1';

  @override
  String get propertiesFontMultipleMaster => 'Multiple Master';

  @override
  String get propertiesFontTrueType => 'TrueType';

  @override
  String get propertiesFontType0 => 'Type 0';

  @override
  String get propertiesFontType3 => 'Type 3';

  @override
  String get propertiesFontOther => 'أخرى';

  @override
  String get propertiesFontColumn => 'الخط';

  @override
  String get propertiesTypeColumn => 'النوع';

  @override
  String get propertiesStatusColumn => 'الحالة';

  @override
  String propertiesDialogTitle(String name) {
    return '$name — الخصائص';
  }

  @override
  String get propertiesSection => 'القسم';

  @override
  String get propertiesSummary => 'ملخّص';

  @override
  String get propertiesAdvanced => 'متقدّم';

  @override
  String get propertiesDone => 'تم';

  @override
  String get propertiesClose => 'إغلاق';

  @override
  String get propertiesEncryption => 'التشفير';

  @override
  String propertiesRc4(String bits) {
    return 'RC4، $bits بت';
  }

  @override
  String get propertiesAes128 => 'AES-128';

  @override
  String get propertiesAes256 => 'AES-256';

  @override
  String get propertiesOwnerPasswordSuffix => 'كلمة مرور المالك';

  @override
  String get propertiesOpenPassword => 'كلمة مرور الفتح';

  @override
  String get propertiesRequired => 'مطلوبة';

  @override
  String get propertiesPermissions => 'الأذونات';

  @override
  String get propertiesPrinting => 'الطباعة';

  @override
  String get propertiesChanging => 'تغيير المستند';

  @override
  String get propertiesCommenting => 'إضافة التعليقات';

  @override
  String get propertiesFilling => 'تعبئة حقول النماذج';

  @override
  String get propertiesSigning => 'التوقيع';

  @override
  String get propertiesCopying => 'نسخ النصوص والصور';

  @override
  String get propertiesScreenReaders => 'وصول قارئات الشاشة إلى النص';

  @override
  String get propertiesAssembling => 'تجميع الصفحات';

  @override
  String get propertiesAllowed => 'مسموح';

  @override
  String get propertiesAllowedHighQuality => 'مسموح، بجودة عالية';

  @override
  String get propertiesNotAllowed => 'غير مسموح';

  @override
  String get propertiesLanguage => 'اللغة';

  @override
  String get propertiesScripts => 'JavaScript';

  @override
  String propertiesScriptsValue(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countText برنامج نصي يعمل عند فتح الملف. لا يشغّلها Ferman أبدًا.',
      many:
          '$countText برنامجًا نصيًا يعمل عند فتح الملف. لا يشغّلها Ferman أبدًا.',
      few: '$countText برامج نصية تعمل عند فتح الملف. لا يشغّلها Ferman أبدًا.',
      two: 'برنامجان نصيان يعملان عند فتح الملف. لا يشغّلهما Ferman أبدًا.',
      one: 'برنامج نصي يعمل عند فتح الملف. لا يشغّله Ferman أبدًا.',
    );
    return '$_temp0';
  }

  @override
  String openingTitle(String name) {
    return 'جارٍ فتح «$name»';
  }

  @override
  String get openingCancel => 'إلغاء';

  @override
  String get defaultAppTitle => 'هل تريد فتح ملفات PDF باستخدام Ferman؟';

  @override
  String get defaultAppDescription =>
      'يمكن أن يكون Ferman التطبيق الذي يُفتح عند النقر المزدوج على ملف PDF. سيطلب منك macOS تأكيد التغيير.';

  @override
  String get defaultAppNow => 'يفتح ملفات PDF الآن:';

  @override
  String get defaultAppNotNow => 'ليس الآن';

  @override
  String get defaultAppUse => 'استخدام Ferman لملفات PDF';

  @override
  String get defaultAppDontAsk => 'عدم السؤال مرة أخرى';

  @override
  String settingsDefaultAppOther(String app) {
    return 'يفتح $app ملفات PDF على جهاز Mac هذا.';
  }

  @override
  String get settingsDefaultAppFerman =>
      'يفتح Ferman ملفات PDF على جهاز Mac هذا.';

  @override
  String attachmentNotSaved(String name) {
    return 'لم يُحفَظ “$name”';
  }

  @override
  String get attachmentWriteFailed =>
      'تعذّر على Ferman كتابة الملف هناك. اختر مجلدًا آخر، أو تحقق من وجود مساحة كافية على القرص ومن أنه لا يزال متصلًا.';

  @override
  String editStepText(String page) {
    return 'تحرير النص · الصفحة $page';
  }

  @override
  String get editHistoryClose => 'إغلاق السجل';

  @override
  String get editHistorySteps => 'الخطوات';

  @override
  String editHistoryOpened(String name) {
    return 'فتح $name';
  }

  @override
  String get editHistoryNote =>
      'انقر على خطوة للعودة إليها. يمكن إعادة الخطوات الرمادية إلى أن تُجري تغييرًا جديدًا. يُحتفظ بالسجل إلى أن تغلق المستند، والإصدارات المحفوظة في سجل الإصدارات.';

  @override
  String get editNothingToUndo => 'لا شيء للتراجع عنه';

  @override
  String get editNothingToRedo => 'لا شيء لإعادته';

  @override
  String get editOverflowTitle => 'النص لا يتسع';

  @override
  String editOverflowBody(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تحتاج الفقرة المعدّلة إلى $n سطر أكثر من إطارها.',
      many: 'تحتاج الفقرة المعدّلة إلى $n سطرًا أكثر من إطارها.',
      few: 'تحتاج الفقرة المعدّلة إلى $n أسطر أكثر من إطارها.',
      two: 'تحتاج الفقرة المعدّلة إلى سطرين أكثر من إطارها.',
      one: 'تحتاج الفقرة المعدّلة إلى سطر واحد أكثر من إطارها.',
    );
    return '$_temp0';
  }

  @override
  String editOverflowExtend(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'توسيع الكتلة بـ$n سطر',
      many: 'توسيع الكتلة بـ$n سطرًا',
      few: 'توسيع الكتلة بـ$n أسطر',
      two: 'توسيع الكتلة بسطرين',
      one: 'توسيع الكتلة بسطر واحد',
    );
    return '$_temp0';
  }

  @override
  String editOverflowTighten(String percent) {
    return 'تضييق التباعد قليلًا (−$percent)';
  }

  @override
  String get editOverflowKeep => 'إبقاء مع تحذير';

  @override
  String editOverflowExtendLabelBelow(String label) {
    return 'سطر $label يقع مباشرة أسفل هذه الكتلة.';
  }

  @override
  String editOverflowExtendBelow(String text) {
    return 'السطر «$text» يقع مباشرة أسفل هذه الكتلة.';
  }

  @override
  String get editOverflowExtendPageEdge =>
      'توسيع الكتلة سيجعلها تتجاوز حافة الصفحة.';

  @override
  String editOverflowTightenShort(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حتى أضيق تباعد مسموح يترك $n سطر زائد.',
      many: 'حتى أضيق تباعد مسموح يترك $n سطرًا زائدًا.',
      few: 'حتى أضيق تباعد مسموح يترك $n أسطر زائدة.',
      two: 'حتى أضيق تباعد مسموح يترك سطرين زائدين.',
      one: 'حتى أضيق تباعد مسموح يترك سطرًا واحدًا زائدًا.',
    );
    return '$_temp0';
  }

  @override
  String editOverflowHidden(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$n سطر مخفي',
      many: '+$n سطرًا مخفيًا',
      few: '+$n أسطر مخفية',
      two: '+سطران مخفيان',
      one: '+سطر واحد مخفي',
    );
    return '$_temp0';
  }

  @override
  String get editTotalsTitle => 'لا تُحدَّث المجاميع';

  @override
  String get editTotalsBody =>
      'يخزّن ملف PDF الأرقام كنص. لا تزال الخلايا المعلّمة تعرض المبالغ القديمة.';

  @override
  String editTotalsReview(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مراجعة الـ$n خلية المعلّمة',
      many: 'مراجعة الـ$n خلية المعلّمة',
      few: 'مراجعة الخلايا الـ$n المعلّمة',
      two: 'مراجعة الخليتين المعلّمتين',
      one: 'مراجعة الخلية المعلّمة',
    );
    return '$_temp0';
  }

  @override
  String get editBadgeEdited => 'معدّل';

  @override
  String get editGlyphTitle => 'حرف مفقود';

  @override
  String editGlyphBody(String chars) {
    return 'لا يحتوي هذا الخط على الحرف $chars. سيستخدم Ferman خطًا مشابهًا لهذا الحرف.';
  }

  @override
  String editGlyphBodyMany(String chars) {
    return 'لا يحتوي هذا الخط على الأحرف $chars. سيستخدم Ferman خطًا مشابهًا لهذه الأحرف.';
  }

  @override
  String get editGlyphChoose => 'اختيار خط…';

  @override
  String get editGlyphKeep => 'إبقاء كما هو';

  @override
  String get editGlyphNoneTitle => 'لا يوجد خط يحتوي هذا الحرف';

  @override
  String editGlyphNoneBody(String chars) {
    return 'لا يحتوي هذا الخط ولا أي خط على هذا الجهاز على الحرف $chars. اختر خطًا يحتويه أو أبقِه كما هو.';
  }

  @override
  String get editGlyphLicenceTitle => 'لا يمكن تضمين هذا الخط';

  @override
  String editGlyphLicenceBody(String font, String chars) {
    return 'خط $font مثبّت، لكن ترخيصه يسمح بالمعاينة والطباعة فقط. سيستخدم Ferman خطًا مشابهًا للحرف $chars بدلًا منه.';
  }

  @override
  String editGlyphLicenceBodyRestricted(String font, String chars) {
    return 'خط $font مثبّت، لكن ترخيصه لا يسمح بتضمينه. سيستخدم Ferman خطًا مشابهًا للحرف $chars بدلًا منه.';
  }

  @override
  String editGlyphOwnFontBody(String font, String chars) {
    return 'يسمح ترخيص خط $font في هذا المستند بالمعاينة والطباعة فقط، لذا لا يعيد Ferman استخدام أحرفه. سيستخدم Ferman خطًا مشابهًا للحرف $chars بدلًا منه.';
  }

  @override
  String get editGlyphAddedTitle => 'أُضيف الحرف من هذا الجهاز';

  @override
  String editGlyphAddedBody(String chars, String font) {
    return 'أخذ Ferman الحرف $chars من خط $font المثبّت على هذا الجهاز وأضافه إلى خط المستند.';
  }

  @override
  String get fontPickerTitle => 'اختيار خط لهذه الكتلة';

  @override
  String get fontPickerClose => 'إغلاق';

  @override
  String get fontPickerScope => 'الاستبدال';

  @override
  String get fontPickerScopeMissing => 'الأحرف المفقودة فقط';

  @override
  String get fontPickerScopeBlock => 'الكتلة كاملة';

  @override
  String get fontPickerSearch => 'البحث في الخطوط';

  @override
  String get fontPickerEmbedded => 'مضمّنة في هذا المستند';

  @override
  String get fontPickerInstalled => 'مثبّتة على هذا الجهاز';

  @override
  String get fontPickerBundled => 'خطوط مشابهة مرفقة مع Ferman';

  @override
  String get fontPickerClosest => 'الأقرب تطابقًا';

  @override
  String fontPickerHas(String chars) {
    return 'يحتوي $chars';
  }

  @override
  String fontPickerHasNone(String chars) {
    return 'لا يحتوي $chars';
  }

  @override
  String fontPickerHasSome(String covered, String needed) {
    return '$covered من $needed أحرف';
  }

  @override
  String get fontPickerNotEmbeddable => 'لا يمكن تضمينه';

  @override
  String fontPickerNoMatch(String query) {
    return 'لا يوجد خط يطابق «$query».';
  }

  @override
  String get fontPickerCancel => 'إلغاء';

  @override
  String fontPickerUse(String font) {
    return 'استخدام $font';
  }

  @override
  String get editFontSubstituted => 'استُبدل الخط';

  @override
  String editFontSubstitutedBody(String font, String chars) {
    return 'تستخدم هذه الكتلة خط $font للحرف $chars.';
  }

  @override
  String get editFontSubstitutedDismiss => 'إغلاق';

  @override
  String get saveAsTitle => 'حفظ باسم';

  @override
  String get saveAsName => 'اسم الملف';

  @override
  String get saveAsNameEmpty => 'أدخل اسم ملف.';

  @override
  String get saveAsNameInvalid => 'لا يمكن أن يحتوي اسم الملف على / أو \\.';

  @override
  String get saveAsNameTaken =>
      'يوجد ملف بهذا الاسم هناك. اختر اسمًا آخر أو استخدم «موقع آخر…».';

  @override
  String get saveAsWhere => 'الموقع';

  @override
  String get saveAsOtherLocation => 'موقع آخر…';

  @override
  String get saveAsFormat => 'التنسيق';

  @override
  String get saveAsPdf => 'PDF';

  @override
  String get saveAsPdfDescription =>
      'ملف PDF قياسي. يبقى النص قابلًا للتحرير في Ferman والمحررات الأخرى.';

  @override
  String get saveAsPdfA => 'PDF/A-2b، للأرشفة';

  @override
  String get saveAsWeb => 'محسّن للويب';

  @override
  String get saveAsCopy => 'حفظ كنسخة';

  @override
  String saveAsCopyDescription(String name, String folder) {
    return 'يبقى «$name» مفتوحًا دون تغيير، وتُحفظ النسخة في $folder.';
  }

  @override
  String get saveAsComments => 'تضمين التعليقات والتعليقات التوضيحية';

  @override
  String get saveAsHistory => 'إزالة سجل التحرير من الملف';

  @override
  String get saveAsCancel => 'إلغاء';

  @override
  String get saveAsClose => 'إغلاق';

  @override
  String saveFailedTitle(String name) {
    return 'تعذّر حفظ «$name»';
  }

  @override
  String get saveFailedDiskFull =>
      'القرص ممتلئ. أفرغ بعض المساحة أو احفظ في مكان آخر. تعديلاتك محفوظة.';

  @override
  String get saveFailedPermission =>
      'ليس لديك إذن بتغيير هذا الملف أو مجلده. احفظه في مكان آخر أو اطلب الإذن من مالكه. تعديلاتك محفوظة.';

  @override
  String get saveFailedLocked =>
      'الملف مفتوح ومقفل في تطبيق آخر. أغلقه هناك ثم أعد المحاولة، أو احفظ نسخة في مكان آخر. تعديلاتك محفوظة.';

  @override
  String get saveFailedRename =>
      'كتب Ferman تغييراتك في ملف مؤقت، لكنه لم يتمكّن من وضعه مكان الملف الأصلي. لم يتغيّر الملف الأصلي، وتعديلاتك محفوظة.';

  @override
  String get saveFailedVolume =>
      'لم يعد القرص الذي يحوي هذا الملف متصلًا. أعد توصيله ثم أعد المحاولة، أو احفظ في مكان آخر. تعديلاتك محفوظة.';

  @override
  String get saveFailedHardLinked =>
      'لهذا الملف روابط أخرى سيكسرها استبداله. احفظه في مكان آخر. تعديلاتك محفوظة.';

  @override
  String get saveFailedNotOwner =>
      'هذا الملف ملك لشخص آخر، ولم يتمكّن Ferman من الإبقاء على مالكه. احفظه في مكان آخر. تعديلاتك محفوظة.';

  @override
  String get saveFailedOther =>
      'تعذّر على Ferman كتابة الملف. أعد المحاولة أو احفظ في مكان آخر. تعديلاتك محفوظة.';

  @override
  String get saveTryAgain => 'إعادة المحاولة';

  @override
  String get saveSomewhereElse => 'الحفظ في مكان آخر…';

  @override
  String get saveAsEllipsis => 'حفظ باسم…';

  @override
  String get saveToastDiskFull =>
      'القرص ممتلئ. أفرغ بعض المساحة أو احفظ في مكان آخر.';

  @override
  String get saveToastOther =>
      'تعديلاتك محفوظة. أعد المحاولة أو احفظ في مكان آخر.';

  @override
  String get saveToastDismiss => 'تجاهل';

  @override
  String fileChangedTitle(String name) {
    return 'تغيّر «$name» على القرص.';
  }

  @override
  String get fileChangedBody =>
      'غيّره تطبيق آخر أو خدمة مزامنة أثناء فتحه. أعد تحميله أو احتفظ بنسختك أو قارن أولًا.';

  @override
  String get fileChangedCompare => 'مقارنة';

  @override
  String get fileChangedKeepMine => 'الاحتفاظ بنسختي';

  @override
  String get fileChangedReload => 'إعادة التحميل';

  @override
  String optimizeTitle(String name) {
    return 'هل تريد تحسين «$name» وتنظيفه؟';
  }

  @override
  String get optimizeSignedBody =>
      'يعيد Ferman كتابة الملف كاملًا دون إصداراته السابقة. لن تبقى تواقيعه صالحة.';

  @override
  String get optimizeAction => 'تحسين وتنظيف';

  @override
  String get saveAsNameInvalidWindows =>
      'لا يمكن أن يحتوي اسم الملف على أيٍّ من هذه: / \\ : * ? \" < > |';

  @override
  String get saveAsNameOpen =>
      'هذا الملف مفتوح في علامة تبويب أخرى. أغلقه هناك أو اختر اسمًا آخر.';

  @override
  String saveAsCopyDescriptionHere(String name) {
    return 'يبقى «$name» مفتوحًا دون تغيير، وتُحفظ النسخة بجواره.';
  }

  @override
  String readOnlyFileTitle(String name) {
    return '«$name» للقراءة فقط.';
  }

  @override
  String get readOnlyFileBody =>
      'لا يستطيع Ferman حفظ التغييرات في هذا الملف. لتحتفظ بتغييراتك، احفظ نسخة.';

  @override
  String get readOnlyFileSaveCopy => 'حفظ نسخة…';

  @override
  String closeUnsavedTitle(String name) {
    return 'هل تريد حفظ التغييرات في «$name»؟';
  }

  @override
  String closeUnsavedBody(String edits) {
    return 'إذا لم تحفظ، ستضيع $edits التي أجريتها في هذه الجلسة.';
  }

  @override
  String closingEdits(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted تعديل',
      many: '$formatted تعديلًا',
      few: '$formatted تعديلات',
      two: 'تعديلان',
      one: 'تعديل واحد',
    );
    return '$_temp0';
  }

  @override
  String get closeUnsavedSave => 'حفظ';

  @override
  String get closeUnsavedDiscard => 'عدم الحفظ';

  @override
  String quitReviewTitle(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted مستند',
      many: '$formatted مستندًا',
      few: '$formatted مستندات',
      two: 'مستندين',
    );
    return 'هل تريد حفظ التغييرات في $_temp0 قبل الإنهاء؟';
  }

  @override
  String get quitReviewBody =>
      'يحفظ Ferman المستندات المحدّدة ثم يُنهي عمله. تضيع تغييرات المستندات غير المحدّدة.';

  @override
  String get quitReviewSave => 'حفظ وإنهاء';

  @override
  String get quitReviewDiscard => 'إنهاء دون حفظ';

  @override
  String recoveryTitle(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted مستند',
      many: '$formatted مستندًا',
      few: '$formatted مستندات',
      two: 'مستندين',
      one: 'مستندًا واحدًا',
    );
    return 'استعاد Ferman $_temp0';
  }

  @override
  String get recoveryBody =>
      'أُغلق Ferman على نحو غير متوقع. كانت في هذه المستندات تغييرات غير محفوظة، واحتفظ Ferman بنسخة من كلٍّ منها على هذا الجهاز.';

  @override
  String get recoveryNote =>
      'تُفتح المستندات المستعادة كغير محفوظة؛ ولم تتغيّر الملفات على القرص. لم يُرسَل أي شيء إلى أي مكان.';

  @override
  String get recoveryDiscard => 'تجاهل النسخ';

  @override
  String recoveryOpen(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فتح $formatted مستند',
      many: 'فتح $formatted مستندًا',
      few: 'فتح $formatted مستندات',
      two: 'فتح المستندين',
      one: 'فتح المستند',
    );
    return '$_temp0';
  }

  @override
  String get recoveryChangedBadge => 'تغيّر على القرص';

  @override
  String get recoveryChangedBody =>
      'تغيّر الملف على القرص بعد نسخة Ferman. تُفتح النسخة المستعادة باسم جديد، فلا يُستبدل أيٌّ منهما.';

  @override
  String get signedTitle => 'هل تريد تحرير مستند موقّع؟';

  @override
  String signedBodyBy(String name, String signer, String date) {
    return 'في «$name» توقيع واحد من $signer بتاريخ $date. أي تغيير في المستند يجعل هذا التوقيع غير صالح.';
  }

  @override
  String signedBody(String name, int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'في «$name» $formatted توقيع. أي تغيير في المستند يجعل هذه التوقيعات غير صالحة.',
      many:
          'في «$name» $formatted توقيعًا. أي تغيير في المستند يجعل هذه التوقيعات غير صالحة.',
      few:
          'في «$name» $formatted توقيعات. أي تغيير في المستند يجعل هذه التوقيعات غير صالحة.',
      two:
          'في «$name» توقيعان. أي تغيير في المستند يجعل هذين التوقيعين غير صالحين.',
      one:
          'في «$name» توقيع واحد. أي تغيير في المستند يجعل هذا التوقيع غير صالح.',
    );
    return '$_temp0';
  }

  @override
  String get signedEditCopy => 'تحرير نسخة';

  @override
  String get signedEditAnyway => 'التحرير على أي حال';

  @override
  String signedCopyHint(String name) {
    return 'تُفتح النسخة في علامة تبويب جديدة باسم «$name». يبقى الأصل الموقّع كما هو.';
  }

  @override
  String signedCopyName(String stem) {
    return '$stem (نسخة)';
  }

  @override
  String signedCopyNameNumbered(String stem, int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return '$stem (نسخة $numberString)';
  }

  @override
  String signedBannerTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم تعد التوقيعات في هذا المستند صالحة.',
      two: 'لم يعد التوقيعان في هذا المستند صالحين.',
      one: 'لم يعد التوقيع في هذا المستند صالحًا.',
    );
    return '$_temp0';
  }

  @override
  String signedBannerBodyBy(String signer) {
    return 'غيّرت المستند بعد أن وقّعه $signer. يبقى التوقيع عند الحفظ، لكنه سيظهر غير صالح.';
  }

  @override
  String get signedBannerBody =>
      'غيّرت المستند بعد توقيعه. تبقى التواقيع عند الحفظ، لكنها ستظهر غير صالحة.';

  @override
  String get signedBannerReview => 'مراجعة التعديلات';

  @override
  String signedReviewRow(String signer) {
    return 'لم يعد توقيع $signer صالحًا';
  }

  @override
  String get signedReviewRowOther => 'لم تعد التواقيع صالحة';

  @override
  String get settingsEditMarks => 'وضع علامة على النص المعدَّل';

  @override
  String get settingsEditMarksNote =>
      'تظهر في Ferman فقط أثناء التحرير. لا تُحفظ في الملف ولا تُطبع أبدًا.';

  @override
  String get settingsMissingGlyphs => 'عندما ينقص خطًّا حرفٌ ما';

  @override
  String get settingsMissingGlyphsSimilar =>
      'استخدام خط مشابه والإشارة إلى ذلك';

  @override
  String get settingsMissingGlyphsAsk => 'السؤال في كل مرة';

  @override
  String get settingsMissingGlyphsMark =>
      'الإبقاء على الخط الأصلي ووضع علامة على الحرف';

  @override
  String get settingsFontForNewText => 'خط النص الجديد';

  @override
  String get settingsFontForNewTextMatch => 'مطابقة النص المحيط';

  @override
  String get settingsKeepVersions => 'الاحتفاظ بالإصدارات';

  @override
  String get settingsKeepVersions30 => '30 يومًا، بجانب الملف';

  @override
  String get settingsReflow =>
      'السماح بإعادة تدفق الفقرات داخل إطارها أثناء الكتابة';

  @override
  String get settingsRecoveryCopies => 'حفظ نسخة استرداد كل دقيقة';

  @override
  String get settingsSaving => 'الحفظ';

  @override
  String get settingsSavingEnd => 'تُضاف التغييرات إلى نهاية الملف';

  @override
  String get settingsSavingEndBody =>
      'يبقى الحفظ سريعًا، وتبقى التواقيع السابقة لتغييراتك سليمة. لا يعيد Ferman كتابة الملف كله إلا عندما تختار «التحسين والتنظيف».';

  @override
  String get settingsOptimize => 'التحسين والتنظيف';

  @override
  String get settingsOptimizeBody =>
      'يعيد كتابة الملف كله لتصغيره. شغّله من لوحة الأوامر؛ لا يُستخدم من تلقاء نفسه أبدًا، ويحذّرك Ferman أولًا إذا كانت التواقيع ستصبح غير صالحة.';

  @override
  String get settingsRecoveryFolder => 'نسخ الاسترداد';
}
