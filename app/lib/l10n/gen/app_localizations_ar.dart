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
  String get onboardingLanguageSearchPlaceholderPhone =>
      'بحث · Search · Ara · Suchen';

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
  String get onboardingEditTitle => 'حرّر أي ملف PDF كما لو كان مستندًا';

  @override
  String get onboardingEditBody =>
      'انقر أي نص واكتب. يحافظ Ferman على الخط الأصلي وحجمه وتباعده، ويعيد توزيع الفقرة داخل إطارها.';

  @override
  String get onboardingEditGlyphs =>
      'عندما يفتقد الخط حرفًا ما، يخبرك Ferman بهذا الحرف وبما سيستخدمه بدلًا منه.';

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
  String get onboardingFeatureEditing => 'تحرير النصوص';

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
  String get settingsPhoneGroupDocuments => 'المستندات';

  @override
  String get settingsPhoneGroupApp => 'التطبيق';

  @override
  String get settingsPhoneGroupRegion => 'المنطقة';

  @override
  String get settingsPhonePrivacyValue => 'لا تُجمع أي بيانات';

  @override
  String get settingsPhoneAbout => 'حول التطبيق والترخيص';

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
    return 'بحث Ferman في $_temp0، مع تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة.';
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
    return 'بحث Ferman في $_temp0.';
  }

  @override
  String get findNotSearchedFields => 'لم يُبحث في حقول النماذج.';

  @override
  String get findNotSearchedBoth => 'لم يُبحث في التعليقات وحقول النماذج.';

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
  String get startPhoneSearch => 'البحث في المستندات';

  @override
  String get startPhoneToolCombine => 'دمج';

  @override
  String get startPhoneToolOcr => 'OCR';

  @override
  String get startPhoneEmptyTitle => 'لا توجد مستندات بعد';

  @override
  String get startPhoneEmptySubtitle =>
      'افتح ملف PDF من هاتفك أو من خدمة سحابية، أو امسح مستندًا ورقيًا.';

  @override
  String get startPhoneOpen => 'فتح ملف';

  @override
  String get startPhoneScan => 'مسح مستند';

  @override
  String get startPhoneSeeAll => 'عرض الكل';

  @override
  String get startPhoneOpenFrom => 'فتح من';

  @override
  String get startPhoneSourceDownloads => 'التنزيلات';

  @override
  String get startPhoneSourceGoogleDrive => 'Google Drive';

  @override
  String get startPhoneSourceOneDrive => 'OneDrive';

  @override
  String get startPhoneRecent => 'الأخيرة';

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
  String get startBadgeEdited => 'معدّل';

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
  String get selectSheetSearch => 'بحث';

  @override
  String get selectSheetNoMatch => 'لا توجد نتائج';

  @override
  String get selectSheetClose => 'إغلاق';

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
  String propertiesPartialMissing(String letters) {
    return 'لا يتضمن $letters.';
  }

  @override
  String get propertiesSubset => 'مجموعة فرعية';

  @override
  String get propertiesSubsetNote => 'الأحرف المستخدمة فقط.';

  @override
  String propertiesSubsetMissing(String letters) {
    return 'كتابة $letters تحتاج إلى خط بديل.';
  }

  @override
  String propertiesShownInstead(String font) {
    return 'يعرض Ferman الخط $font بدلًا منه.';
  }

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
  String editGlyphMarkedBody(String chars) {
    return 'لا يحتوي هذا الخط على $chars. يُبقي Ferman الخط الأصلي ويضع علامة على ما ينقصه.';
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
  String get saveFailedNoRecoveryCopy =>
      'لا توجد نسخة استرداد: تعذّر على Ferman كتابتها أيضًا، لذا تبقى هذه التعديلات في هذه النافذة فقط حتى تحفظ.';

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
  String get recoveryFileSuffix => 'مستعاد';

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

  @override
  String shellZoomTypeHint(String min, String max) {
    return 'اكتب نسبة تكبير من $min إلى $max';
  }

  @override
  String get shellEditForbidden => 'لا يسمح المؤلف بالتحرير';

  @override
  String get editPanelTipClick =>
      'انقر على أي نص لتحديد كتلته. انقر مرة أخرى لوضع المؤشر.';

  @override
  String editPanelTipKeys(String key) {
    return 'ينتقل Tab بين الكتل ويبدأ Enter التحرير. اضغط مع الاستمرار على $key لإظهار كل الكتل.';
  }

  @override
  String get editPanelInSession => 'في هذه الجلسة';

  @override
  String get editPanelReview => 'مراجعة';

  @override
  String get languageNameGerman => 'الألمانية';

  @override
  String get languageNameJapanese => 'اليابانية';

  @override
  String languageWithRegion(String language, String region) {
    return '$language ($region)';
  }

  @override
  String get editLanguage => 'اللغة';

  @override
  String get editCheckSpelling => 'التدقيق الإملائي';

  @override
  String get editHyphenate => 'الوصل بشرطة';

  @override
  String editStepLanguage(String page) {
    return 'تغيير اللغة · الصفحة $page';
  }

  @override
  String get reviewClose => 'إغلاق المراجعة';

  @override
  String get reviewShow => 'عرض';

  @override
  String get reviewFilterAll => 'الكل';

  @override
  String get reviewFilterText => 'النص';

  @override
  String get reviewFilterFonts => 'الخطوط';

  @override
  String get reviewFilterWarnings => 'التحذيرات';

  @override
  String get reviewEmptyTitle => 'لا توجد تعديلات بعد';

  @override
  String get reviewEmptyBody =>
      'تظهر هنا التغييرات التي تجريها في هذه الجلسة. تُمسح القائمة عند إغلاق المستند، والجلسات السابقة في سجل الإصدارات.';

  @override
  String get reviewNothing => 'لا توجد تعديلات بعد';

  @override
  String get reviewRevertAll => 'التراجع عن الكل…';

  @override
  String get reviewExportList => 'تصدير القائمة…';

  @override
  String get reviewGoTo => 'الانتقال';

  @override
  String get reviewRevert => 'تراجع';

  @override
  String get reviewStepReverted => 'تم التراجع عن تعديل';

  @override
  String get reviewStepRevertedAll => 'تم التراجع عن كل التعديلات';

  @override
  String get reviewWhereSignature => 'التوقيع';

  @override
  String reviewWhereSignaturePage(String page) {
    return 'الصفحة $page · التوقيع';
  }

  @override
  String reviewWhereText(String page) {
    return 'الصفحة $page · النص';
  }

  @override
  String reviewWhereFont(String page) {
    return 'الصفحة $page · الخط';
  }

  @override
  String reviewWhereWarning(String page) {
    return 'الصفحة $page · تحذير محفوظ';
  }

  @override
  String reviewExportName(String name) {
    return 'تعديلات $name';
  }

  @override
  String get reviewExportFailed => 'تعذّر حفظ القائمة.';

  @override
  String reviewRevertAllBody(String name) {
    return 'يعود «$name» إلى ما كان عليه عند فتحه. يمكنك استعادة التعديلات بالأمر «تراجع» حتى تغلق المستند.';
  }

  @override
  String reviewDependentBody(String later, String change) {
    return 'كُتب «$later» في الجملة بعد هذا التغيير. التراجع عن «$change» يزيله أيضًا.';
  }

  @override
  String reviewDependentsBody(int count, String shown, String change) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'يعتمد $shown تعديل لاحق على هذا التغيير. التراجع عن «$change» يزيلها أيضًا.',
      many:
          'يعتمد $shown تعديلًا لاحقًا على هذا التغيير. التراجع عن «$change» يزيلها أيضًا.',
      few:
          'تعتمد $shown تعديلات لاحقة على هذا التغيير. التراجع عن «$change» يزيلها أيضًا.',
      two:
          'يعتمد تعديلان لاحقان على هذا التغيير. التراجع عن «$change» يزيلها أيضًا.',
    );
    return '$_temp0';
  }

  @override
  String reviewKeptWarning(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown سطر مخفي — أُبقي التجاوز',
      many: '$shown سطرًا مخفيًا — أُبقي التجاوز',
      few: '$shown أسطر مخفية — أُبقي التجاوز',
      two: 'سطران مخفيان — أُبقي التجاوز',
      one: '$shown سطر مخفي — أُبقي التجاوز',
    );
    return '$_temp0';
  }

  @override
  String reviewRevertAllTitle(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هل تريد التراجع عن التعديلات الـ$shown كلها؟',
      one: 'هل تريد التراجع عن التعديل؟',
    );
    return '$_temp0';
  }

  @override
  String reviewRevertAllButton(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التراجع عن $shown تعديل',
      many: 'التراجع عن $shown تعديلًا',
      few: 'التراجع عن $shown تعديلات',
      two: 'التراجع عن تعديلين',
      one: 'التراجع عن تعديل واحد',
    );
    return '$_temp0';
  }

  @override
  String reviewDependentTitle(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هل تريد أيضًا التراجع عن التعديلات الـ$shown المعتمدة عليه؟',
      one: 'هل تريد أيضًا التراجع عن التعديل المعتمد عليه؟',
    );
    return '$_temp0';
  }

  @override
  String reviewDependentButton(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التراجع عن الـ$shown كلها',
      one: 'التراجع عن كليهما',
    );
    return '$_temp0';
  }

  @override
  String get editPanelTitle => 'كتلة نص';

  @override
  String get editPanelText => 'النص';

  @override
  String get editPanelSize => 'الحجم';

  @override
  String get editPanelColour => 'لون النص';

  @override
  String get editPanelColoursDocument => 'في هذا المستند';

  @override
  String get editPanelColoursStandard => 'قياسية';

  @override
  String get editPanelFontsDocument => 'في هذا المستند';

  @override
  String get editPanelFontsDevice => 'على هذا الجهاز';

  @override
  String get editPanelBold => 'غامق';

  @override
  String get editPanelItalic => 'مائل';

  @override
  String get editPanelUnderline => 'تسطير';

  @override
  String get editPanelNoBold =>
      'لا يتوفر لهذا الخط على هذا الكمبيوتر وزن آخر يمكنه رسم هذا النص.';

  @override
  String get editPanelNoItalic =>
      'لا يتوفر لهذا الخط على هذا الكمبيوتر شكل مائل يمكنه رسم هذا النص.';

  @override
  String get editPanelNoUnderline =>
      'لا يوجد في خطوط PDF شكل مسطّر للتبديل إليه، ولا يرسم Ferman تسطيرًا زائفًا.';

  @override
  String get editPanelAlignment => 'المحاذاة';

  @override
  String get editPanelAlignLeft => 'محاذاة لليسار';

  @override
  String get editPanelAlignCenter => 'توسيط';

  @override
  String get editPanelAlignRight => 'محاذاة لليمين';

  @override
  String get editPanelAlignJustify => 'ضبط';

  @override
  String get editPanelSpacing => 'التباعد';

  @override
  String get editPanelCharacter => 'الأحرف';

  @override
  String get editPanelLine => 'الأسطر';

  @override
  String get editPanelBefore => 'قبل';

  @override
  String get editPanelAfter => 'بعد';

  @override
  String get editPanelPosition => 'الموضع والحجم';

  @override
  String get editPanelWidth => 'العرض';

  @override
  String get editPanelHeight => 'الارتفاع';

  @override
  String get editPanelReset => 'إعادة تعيين نمط النص';

  @override
  String get editPanelHint =>
      'يُعاد تدفق النص داخل الإطار. اسحب مقبضًا لتغيير الحجم.';

  @override
  String get editBarLabel => 'تنسيق التحديد';

  @override
  String get editBarLink => 'إضافة رابط';

  @override
  String get editBarHighlight => 'تمييز (يضيف تعليقًا)';

  @override
  String get editBarComment => 'التعليق على التحديد';

  @override
  String get editBarReplace => 'البحث عن هذه الكلمات واستبدالها';

  @override
  String editStepStyle(String page) {
    return 'تغيير نمط النص · الصفحة $page';
  }

  @override
  String editStepMoved(String page) {
    return 'نقل كتلة النص · الصفحة $page';
  }

  @override
  String editStepResized(String page) {
    return 'تغيير حجم كتلة النص · الصفحة $page';
  }

  @override
  String get phoneSections => 'الأقسام';

  @override
  String get phoneTabHome => 'الرئيسية';

  @override
  String get phoneTabFiles => 'الملفات';

  @override
  String get phoneTabScan => 'مسح';

  @override
  String get phoneTabSettings => 'الإعدادات';

  @override
  String jobPageOf(String page, String pages) {
    return 'الصفحة $page من $pages';
  }

  @override
  String jobPausedAtPage(String page) {
    return 'متوقفة مؤقتًا عند الصفحة $page';
  }

  @override
  String get jobFailedDiskFull =>
      'القرص ممتلئ. أفرغ بعض المساحة ثم حاول مرة أخرى.';

  @override
  String jobCopyingTitle(String name) {
    return 'جارٍ نسخ $name';
  }

  @override
  String jobCopiedTitle(String name) {
    return 'تم نسخ $name';
  }

  @override
  String jobCopyFailedTitle(String name) {
    return 'تعذّر نسخ $name';
  }

  @override
  String get tasksTitle => 'المهام في الخلفية';

  @override
  String get tasksClose => 'إغلاق اللوحة';

  @override
  String get tasksOpen => 'إظهار المهام في الخلفية أو إخفاؤها';

  @override
  String get tasksEmptyTitle => 'لا توجد مهام في الخلفية';

  @override
  String get tasksEmptyBody =>
      'تُنفَّذ هنا الأعمال الطويلة، مثل ضغط ملف، بينما تواصل عملك.';

  @override
  String tasksRunning(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted مهمة قيد التنفيذ',
      many: '$formatted مهمةً قيد التنفيذ',
      few: '$formatted مهام قيد التنفيذ',
      two: 'مهمتان قيد التنفيذ',
      one: 'مهمة واحدة قيد التنفيذ',
    );
    return '$_temp0';
  }

  @override
  String get taskPause => 'إيقاف مؤقت';

  @override
  String get taskResume => 'متابعة';

  @override
  String get taskShow => 'إظهار';

  @override
  String get taskDismiss => 'إغلاق';

  @override
  String taskCancelTitle(String task) {
    return 'هل تريد إلغاء ”$task“؟';
  }

  @override
  String get taskCancelBody =>
      'يُتجاهل ما أُنجز منها حتى الآن، ولا يبقى أي ملف.';

  @override
  String get taskKeepRunning => 'متابعة التنفيذ';

  @override
  String get taskCancelConfirm => 'إلغاء المهمة';

  @override
  String tasksQuitTitle(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لا تزال $formatted مهمة قيد التنفيذ في الخلفية',
      many: 'لا تزال $formatted مهمةً قيد التنفيذ في الخلفية',
      few: 'لا تزال $formatted مهام قيد التنفيذ في الخلفية',
      two: 'لا تزال مهمتان قيد التنفيذ في الخلفية',
      one: 'لا تزال مهمة واحدة قيد التنفيذ في الخلفية',
    );
    return '$_temp0';
  }

  @override
  String get tasksQuitBody =>
      'يؤدي الإنهاء إلى إلغائها، ولا تترك ملفات غير مكتملة.';

  @override
  String get tasksQuitKeep => 'مواصلة العمل';

  @override
  String get tasksQuitConfirm => 'إلغاء المهام والإنهاء';

  @override
  String get organizeGridLabel => 'الصفحات';

  @override
  String get organizePanelLabel => 'التحديد';

  @override
  String organizeHintSelected(int total, String selected, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$selected من $pages صفحة محددة',
      few: '$selected من $pages صفحات محددة',
      two: '$selected من صفحتين محددة',
      one: '$selected من صفحة واحدة محددة',
    );
    return '$_temp0';
  }

  @override
  String organizeHintMoving(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'جارٍ نقل $n صفحة',
      few: 'جارٍ نقل $n صفحات',
      two: 'جارٍ نقل صفحتين',
      one: 'جارٍ نقل صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String organizePanelTitle(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n صفحة محددة',
      few: '$n صفحات محددة',
      two: 'صفحتان محددتان',
      one: 'صفحة واحدة محددة',
    );
    return '$_temp0';
  }

  @override
  String get organizePanelPages => 'الصفحات';

  @override
  String organizePanelPagesLabels(String pages, String labels) {
    return '$pages (التسميات $labels)';
  }

  @override
  String get organizePanelSize => 'الحجم';

  @override
  String get organizePanelRotation => 'التدوير';

  @override
  String get organizePanelMixed => 'متنوع';

  @override
  String get organizePanelCommands => 'الأوامر';

  @override
  String get organizePanelExtract => 'استخراج…';

  @override
  String get organizePanelReplace => 'استبدال…';

  @override
  String organizePanelInsertAfter(String page) {
    return 'إدراج بعد الصفحة $page';
  }

  @override
  String get organizePanelBlankPage => 'صفحة فارغة';

  @override
  String get organizePanelFromFile => 'صفحات من ملف…';

  @override
  String get organizePanelFromScanner => 'من ماسح ضوئي أو كاميرا…';

  @override
  String organizePagesCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n صفحة',
      few: '$n صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get organizeMenuExtract => 'استخراج كملف PDF جديد…';

  @override
  String get organizeMenuInsertBlank => 'إدراج صفحة فارغة بعدها';

  @override
  String get organizeMenuInsertFile => 'إدراج صفحات من ملف…';

  @override
  String get organizeMenuReplace => 'استبدال بصفحات من ملف…';

  @override
  String organizeMenuDelete(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $n صفحة',
      few: 'حذف $n صفحات',
      two: 'حذف صفحتين',
      one: 'حذف صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get organizeDeleteAllReason =>
      'يجب أن يحتفظ المستند بصفحة واحدة على الأقل';

  @override
  String organizeToastDeleted(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُذفت $n صفحة',
      few: 'حُذفت $n صفحات',
      two: 'حُذفت صفحتان',
      one: 'حُذفت صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String organizeToastRotated(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دُوّرت $n صفحة',
      few: 'دُوّرت $n صفحات',
      two: 'دُوّرت صفحتان',
      one: 'دُوّرت صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String organizeToastDuplicated(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كُررت $n صفحة',
      few: 'كُررت $n صفحات',
      two: 'كُررت صفحتان',
      one: 'كُررت صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String organizeToastMoved(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نُقلت $n صفحة',
      few: 'نُقلت $n صفحات',
      two: 'نُقلت صفحتان',
      one: 'نُقلت صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String organizeToastInserted(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُدرجت $n صفحة',
      few: 'أُدرجت $n صفحات',
      two: 'أُدرجت صفحتان',
      one: 'أُدرجت صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String organizeToastPages(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الصفحات $pages',
      one: 'الصفحة $pages',
    );
    return '$_temp0';
  }

  @override
  String organizeToastDeletedNote(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$pages. تبقى في الملف إلى أن تحفظ مع «إزالة سجل التحرير» أو تشغّل «تحسين وتنظيف».',
      one:
          '$pages. تبقى في الملف إلى أن تحفظ مع «إزالة سجل التحرير» أو تشغّل «تحسين وتنظيف».',
    );
    return '$_temp0';
  }

  @override
  String organizeStepInsert(String name) {
    return 'إدراج $name';
  }

  @override
  String get organizeFailed => 'لم تتغير الصفحات';

  @override
  String organizeInsertFailed(String name) {
    return 'تعذّر إدراج $name';
  }

  @override
  String organizeDropMoveBefore(int count, String pages, String before) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أفلت لنقل الصفحات $pages قبل الصفحة $before',
      one: 'أفلت لنقل الصفحة $pages قبل الصفحة $before',
    );
    return '$_temp0';
  }

  @override
  String organizeDropMoveEnd(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أفلت لنقل الصفحات $pages إلى النهاية',
      one: 'أفلت لنقل الصفحة $pages إلى النهاية',
    );
    return '$_temp0';
  }

  @override
  String organizeDropFilesBefore(String before) {
    return 'أفلت للإدراج قبل الصفحة $before';
  }

  @override
  String get organizeDropFilesEnd => 'أفلت للإدراج في النهاية';

  @override
  String jobInsertingTitle(String name) {
    return 'جارٍ قراءة الصفحات من $name';
  }

  @override
  String jobInsertedTitle(String name) {
    return 'أُدرجت الصفحات من $name';
  }

  @override
  String get organizeSelectFirst => 'حدد الصفحات أولًا';

  @override
  String get organizeCancel => 'إلغاء';

  @override
  String get organizeFailedTitle => 'تعذّر تغيير الصفحات';

  @override
  String organizeBadRange(String last) {
    return 'اكتب الصفحات بهذا الشكل: 1–3، 5، حتى الصفحة $last.';
  }

  @override
  String organizeSizeA4(String size) {
    return 'A4 · $size';
  }

  @override
  String organizeSizeLetter(String size) {
    return 'Letter · $size';
  }

  @override
  String get organizeSizeCustom => 'مخصّص…';

  @override
  String get organizeWidth => 'العرض';

  @override
  String get organizeHeight => 'الارتفاع';

  @override
  String get cropTitle => 'الاقتصاص وحجم الصفحة';

  @override
  String get cropMargins => 'الهوامش';

  @override
  String get cropTop => 'أعلى';

  @override
  String get cropBottom => 'أسفل';

  @override
  String get cropLeft => 'يسار';

  @override
  String get cropRight => 'يمين';

  @override
  String get cropRemoveWhite => 'إزالة الهوامش البيضاء';

  @override
  String get cropNoContent => 'لا يوجد في هذه الصفحات محتوى يمكن قياسه.';

  @override
  String cropTooMuch(String page) {
    return 'لا تُبقي هذه الهوامش شيئًا من الصفحة $page.';
  }

  @override
  String get cropPageSize => 'حجم الصفحة';

  @override
  String cropKeepSize(String size) {
    return 'الإبقاء على الحجم الحالي ($size)';
  }

  @override
  String get cropContent => 'المحتوى';

  @override
  String get cropFitCentre => 'توسيط';

  @override
  String get cropFitScale => 'تغيير الحجم للملاءمة';

  @override
  String get cropApplyTo => 'التطبيق على';

  @override
  String get cropThisPage => 'هذه الصفحة';

  @override
  String cropAllPages(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل الصفحات الـ$formatted',
      many: 'كل الصفحات الـ$formatted',
      few: 'كل الصفحات الـ$formatted',
      two: 'الصفحتان كلتاهما',
      one: 'الصفحة الوحيدة',
      zero: 'كل الصفحات',
    );
    return '$_temp0';
  }

  @override
  String get cropSomePages => 'الصفحات';

  @override
  String get cropWhichPages => 'أي الصفحات';

  @override
  String get cropParityAll => 'كل الصفحات في النطاق';

  @override
  String get cropParityOdd => 'الصفحات الفردية';

  @override
  String get cropParityEven => 'الصفحات الزوجية';

  @override
  String cropAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اقتصاص $formatted صفحة',
      many: 'اقتصاص $formatted صفحة',
      few: 'اقتصاص $formatted صفحات',
      two: 'اقتصاص صفحتين',
      one: 'اقتصاص صفحة واحدة',
      zero: 'اقتصاص',
    );
    return '$_temp0';
  }

  @override
  String cropResizeAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تغيير حجم $formatted صفحة',
      many: 'تغيير حجم $formatted صفحة',
      few: 'تغيير حجم $formatted صفحات',
      two: 'تغيير حجم صفحتين',
      one: 'تغيير حجم صفحة واحدة',
      zero: 'تغيير الحجم',
    );
    return '$_temp0';
  }

  @override
  String cropDone(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اقتُصت $formatted صفحة',
      many: 'اقتُصت $formatted صفحة',
      few: 'اقتُصت $formatted صفحات',
      two: 'اقتُصت صفحتان',
      one: 'اقتُصت صفحة واحدة',
      zero: 'لم تُقتص أي صفحة',
    );
    return '$_temp0';
  }

  @override
  String get cropDoneHidden => 'ما يقع خارج الإطار مخفي وليس محذوفًا.';

  @override
  String get cropStep => 'اقتصاص الصفحات';

  @override
  String get cropSizeStep => 'تغيير حجم الصفحة';

  @override
  String get labelsTitle => 'تسميات الصفحات';

  @override
  String get labelsDescription =>
      'اختر طريقة ترقيم الصفحات في Ferman وفي تطبيقات PDF الأخرى وعند الطباعة.';

  @override
  String get labelsColumnPages => 'الصفحات';

  @override
  String get labelsColumnStyle => 'النمط';

  @override
  String get labelsColumnPrefix => 'البادئة';

  @override
  String get labelsColumnStart => 'البدء من';

  @override
  String get labelsPrefixNone => 'بلا';

  @override
  String get labelsStyleRomanLower => 'i, ii, iii';

  @override
  String get labelsStyleRomanUpper => 'I, II, III';

  @override
  String get labelsStyleDecimal => '1, 2, 3';

  @override
  String get labelsStyleLettersLower => 'a, b, c';

  @override
  String get labelsStyleLettersUpper => 'A, B, C';

  @override
  String get labelsStyleNone => 'البادئة فقط';

  @override
  String get labelsRemoveRange => 'إزالة النطاق';

  @override
  String get labelsAddRange => 'إضافة نطاق';

  @override
  String get labelsPreview => 'معاينة';

  @override
  String get labelsPrint => 'طباعة الأرقام على الصفحات أيضًا';

  @override
  String get labelsPrintNote =>
      'تُضاف في تذييل الصفحة. وتُتخطى الصفحات التي تعرض رقمًا بالفعل.';

  @override
  String get labelsApply => 'تطبيق التسميات';

  @override
  String get labelsStep => 'تغيير تسميات الصفحات';

  @override
  String labelsErrorInvalid(String row) {
    return 'الصف $row: اكتب صفحاته بهذا الشكل: 1–9.';
  }

  @override
  String labelsErrorOverlap(String row) {
    return 'يتداخل الصف $row مع النطاق الذي قبله.';
  }

  @override
  String labelsErrorPast(String row, String last) {
    return 'يتجاوز الصف $row الصفحة الأخيرة، $last.';
  }

  @override
  String labelsErrorUncovered(String page) {
    return 'الصفحة $page ليست في أي نطاق. يجب أن تشمل النطاقات كل الصفحات.';
  }

  @override
  String get insertMenuBlank => 'صفحة فارغة';

  @override
  String get insertMenuFile => 'صفحات من ملف…';

  @override
  String get insertMenuScan => 'من الماسح الضوئي أو الكاميرا…';

  @override
  String get insertBlankTitle => 'إدراج صفحة فارغة';

  @override
  String get insertSize => 'الحجم';

  @override
  String insertSameSize(String page, String size) {
    return 'مثل الصفحة $page ($size)';
  }

  @override
  String get insertOrientation => 'الاتجاه';

  @override
  String get insertPortrait => 'طولي';

  @override
  String get insertLandscape => 'عرضي';

  @override
  String get insertCount => 'عدد الصفحات';

  @override
  String get insertPosition => 'الموضع';

  @override
  String get insertBefore => 'قبل';

  @override
  String get insertAfter => 'بعد';

  @override
  String get insertPage => 'الصفحة';

  @override
  String insertAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إدراج $formatted صفحة',
      many: 'إدراج $formatted صفحة',
      few: 'إدراج $formatted صفحات',
      two: 'إدراج صفحتين',
      one: 'إدراج صفحة واحدة',
      zero: 'إدراج',
    );
    return '$_temp0';
  }

  @override
  String get insertBlankStep => 'إدراج صفحة فارغة';

  @override
  String get insertFileTitle => 'إدراج صفحات من ملف';

  @override
  String get insertFileAction => 'إدراج الصفحات';

  @override
  String get insertFileStep => 'إدراج صفحات من ملف';

  @override
  String get sourceChoose => 'اختيار ملف…';

  @override
  String get sourceNone => 'لم يُختر أي ملف';

  @override
  String sourcePagesInfo(int count, String name, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $formatted صفحة',
      many: '$name · $formatted صفحة',
      few: '$name · $formatted صفحات',
      two: '$name · صفحتان',
      one: '$name · صفحة واحدة',
      zero: '$name',
    );
    return '$_temp0';
  }

  @override
  String get sourceRange => 'الصفحات من الملف';

  @override
  String get sourceAllPages => 'كل الصفحات';

  @override
  String get sourceUnlock => 'فتح القفل';

  @override
  String get sourceForbidden =>
      'لا يسمح هذا الملف بأخذ صفحات منه. وترفع كلمة مرور المالك هذا القيد.';

  @override
  String get sourceUnreadable => 'يتعذّر على Ferman قراءة هذا الملف.';

  @override
  String get replaceTitle => 'استبدال الصفحات';

  @override
  String get replaceThese => 'الصفحات في هذا المستند';

  @override
  String get replaceFewer => 'يوفّر الملف صفحات أقل: ستُحذف بقية هذه الصفحات.';

  @override
  String get replaceMore =>
      'يوفّر الملف صفحات أكثر: ستأتي الصفحات الزائدة بعد الأخيرة.';

  @override
  String replaceAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استبدال $formatted صفحة',
      many: 'استبدال $formatted صفحة',
      few: 'استبدال $formatted صفحات',
      two: 'استبدال صفحتين',
      one: 'استبدال صفحة واحدة',
      zero: 'استبدال',
    );
    return '$_temp0';
  }

  @override
  String get replaceStep => 'استبدال الصفحات';

  @override
  String get extractTitle => 'استخراج الصفحات';

  @override
  String get extractPages => 'الصفحات';

  @override
  String get extractOneFile => 'ملف واحد';

  @override
  String get extractEachFile => 'ملف لكل صفحة';

  @override
  String get extractDelete => 'حذف هذه الصفحات بعد ذلك';

  @override
  String get extractDeleteAll => 'يجب أن تبقى في المستند صفحة واحدة على الأقل.';

  @override
  String get extractAction => 'استخراج…';

  @override
  String extractFileName(String document, String pages) {
    return '$document الصفحات $pages';
  }

  @override
  String get extractDeleteStep => 'حذف الصفحات';

  @override
  String jobExtractingTitle(String name) {
    return 'جارٍ استخراج صفحات $name';
  }

  @override
  String jobExtractedTitle(String name) {
    return 'استُخرجت صفحات $name';
  }

  @override
  String jobExtractFailedTitle(String name) {
    return 'تعذّر استخراج صفحات $name';
  }

  @override
  String jobInsertFailedTitle(String name) {
    return 'تعذّر إدراج الصفحات من $name';
  }

  @override
  String jobReplacingTitle(String name) {
    return 'جارٍ قراءة الصفحات البديلة من $name';
  }

  @override
  String jobReplacedTitle(String name) {
    return 'استُبدلت الصفحات بـ$name';
  }

  @override
  String jobReplaceFailedTitle(String name) {
    return 'تعذّر استبدال الصفحات بـ$name';
  }

  @override
  String organizeFileCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted ملف',
      many: '$formatted ملفًا',
      few: '$formatted ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String organizePageCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted صفحة',
      many: '$formatted صفحة',
      few: '$formatted صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get combineAddFiles => 'إضافة ملفات…';

  @override
  String get combineFilter => 'ملفات PDF والصور وملفات Office';

  @override
  String get combineEmptyTitle => 'لا توجد ملفات بعد';

  @override
  String get combineEmptyBody =>
      'أضف ملفات PDF أو صورًا لدمجها في ملف جديد واحد.';

  @override
  String get combineDrag => 'اسحب لإعادة الترتيب';

  @override
  String get combineMoveUp => 'نقل لأعلى';

  @override
  String get combineMoveDown => 'نقل لأسفل';

  @override
  String get combinePagesToInclude => 'الصفحات المراد تضمينها';

  @override
  String get combineAllPages => 'الكل';

  @override
  String get combineRemoveFile => 'إزالة الملف';

  @override
  String get combineMetaImage => 'صورة · تُحوَّل إلى صفحة واحدة';

  @override
  String get combineMetaOffice => 'Word أو Excel';

  @override
  String get combineNeedsPassword => 'مقفل: أدخل كلمة المرور لإضافته.';

  @override
  String get combineWrongPassword => 'كلمة المرور هذه لا تفتحه. حاول مرة أخرى.';

  @override
  String get combineOwnerPassword =>
      'يمنع هذا الملف الدمج. أدخل كلمة مرور المالك لإضافته.';

  @override
  String get combineUnreadable => 'يتعذر على Ferman قراءة هذا الملف.';

  @override
  String get combineBadRange => 'لا يحتوي هذا الملف على تلك الصفحات.';

  @override
  String get combinePassword => 'كلمة المرور';

  @override
  String get combineUnlock => 'فتح القفل';

  @override
  String get combineNotProtected => 'لن يحمل الملف الجديد كلمة مرور هذا الملف.';

  @override
  String get combineNotSigned => 'لن تنتقل تواقيعه إلى الملف الجديد.';

  @override
  String get combineNewFile => 'ملف جديد';

  @override
  String get combineDefaultName => 'ملف مدمج.pdf';

  @override
  String get combineBookmarks => 'إضافة إشارة مرجعية لكل ملف';

  @override
  String get combineKeepForms => 'الاحتفاظ بحقول النماذج';

  @override
  String get combineKeepFormsNote => 'لا تنتقل التواقيع من الملفات الأصلية.';

  @override
  String combineAbout(String size) {
    return 'حوالى $size';
  }

  @override
  String combineAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دمج $formatted ملف',
      many: 'دمج $formatted ملفًا',
      few: 'دمج $formatted ملفات',
      two: 'دمج ملفين',
      one: 'دمج ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String combineResult(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'النتيجة · $formatted صفحة',
      many: 'النتيجة · $formatted صفحة',
      few: 'النتيجة · $formatted صفحات',
      two: 'النتيجة · صفحتان',
      one: 'النتيجة · صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String combineResultPage(String page, String file) {
    return 'الصفحة $page، من الملف $file';
  }

  @override
  String combineOutputExists(String name) {
    return '“$name” موجود بالفعل. اختر اسمًا آخر.';
  }

  @override
  String splitTitle(String name) {
    return 'تقسيم “$name”';
  }

  @override
  String get splitBy => 'طريقة التقسيم';

  @override
  String get splitEvery => 'كل بضع صفحات';

  @override
  String get splitEveryBody => 'ملف جديد كل N صفحة.';

  @override
  String get splitBookmarks => 'عند الإشارات المرجعية العليا';

  @override
  String splitBookmarksBody(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ملف لكل فصل. عُثر على $formatted إشارة مرجعية.',
      many: 'ملف لكل فصل. عُثر على $formatted إشارة مرجعية.',
      few: 'ملف لكل فصل. عُثر على $formatted إشارات مرجعية.',
      two: 'ملف لكل فصل. عُثر على إشارتين مرجعيتين.',
      one: 'ملف لكل فصل. عُثر على إشارة مرجعية واحدة.',
    );
    return '$_temp0';
  }

  @override
  String get splitNoBookmarks => 'لا يحتوي هذا المستند على إشارات مرجعية.';

  @override
  String get splitSize => 'حسب حجم الملف';

  @override
  String get splitSizeBody =>
      'ملفات لا تتجاوز حجمًا تختاره، لتناسب حدود البريد الإلكتروني.';

  @override
  String get splitBlank => 'عند الصفحات الفارغة';

  @override
  String get splitBlankBody => 'تُزال الصفحات الفارغة الفاصلة.';

  @override
  String get splitNoBlankPages => 'لم يُعثر على صفحات فارغة.';

  @override
  String get splitPagesPerFile => 'عدد الصفحات لكل ملف';

  @override
  String get splitLargest => 'أكبر ملف';

  @override
  String get splitFileNames => 'أسماء الملفات';

  @override
  String get splitSaveTo => 'الحفظ في';

  @override
  String get splitSameFolder => 'مجلد الملف الأصلي نفسه';

  @override
  String get splitChooseFolder => 'اختيار مجلد…';

  @override
  String get splitOverLimit => 'صفحة واحدة وحدها أكبر من هذا الحجم.';

  @override
  String get splitNotProtected =>
      'لن تحمل الملفات الجديدة كلمة مرور هذا المستند.';

  @override
  String get splitNotSigned => 'لن تحمل الملفات الجديدة تواقيعه.';

  @override
  String splitAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تقسيم إلى $formatted ملف',
      many: 'تقسيم إلى $formatted ملفًا',
      few: 'تقسيم إلى $formatted ملفات',
      two: 'تقسيم إلى ملفين',
      one: 'تقسيم إلى ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String get createBlank => 'صفحة فارغة';

  @override
  String get createFromFiles => 'من ملفات…';

  @override
  String get createFromClipboard => 'من الحافظة';

  @override
  String get createDefaultName => 'بلا عنوان.pdf';

  @override
  String jobSplittingTitle(String name) {
    return 'جارٍ تقسيم $name';
  }

  @override
  String jobSplitTitle(String name) {
    return 'تم تقسيم $name';
  }

  @override
  String jobSplitFailedTitle(String name) {
    return 'تعذر تقسيم $name';
  }

  @override
  String jobCombiningTitle(String name) {
    return 'جارٍ الدمج في $name';
  }

  @override
  String jobCombinedTitle(String name) {
    return 'تم الدمج في $name';
  }

  @override
  String jobCombineFailedTitle(String name) {
    return 'تعذر الدمج في $name';
  }

  @override
  String jobCreatingTitle(String name) {
    return 'جارٍ إنشاء $name';
  }

  @override
  String jobCreatedTitle(String name) {
    return 'تم إنشاء $name';
  }

  @override
  String jobCreateFailedTitle(String name) {
    return 'تعذر إنشاء $name';
  }

  @override
  String get commentsTitle => 'التعليقات';

  @override
  String get commentsFilter => 'تصفية وفرز';

  @override
  String get commentsMore => 'المزيد: تصدير الملخص، التسطيح، إخفاء الكل';

  @override
  String get commentsStatus => 'الحالة';

  @override
  String commentsStatusOpen(String count) {
    return 'مفتوحة $count';
  }

  @override
  String commentsStatusResolved(String count) {
    return 'محلولة $count';
  }

  @override
  String commentsStatusAll(String count) {
    return 'الكل $count';
  }

  @override
  String get commentsFilterAuthor => 'المؤلف';

  @override
  String get commentsFilterType => 'النوع';

  @override
  String get commentsFilterSort => 'الفرز';

  @override
  String get commentsAllPeople => 'جميع الأشخاص';

  @override
  String get commentsTypeNotes => 'الملاحظات';

  @override
  String get commentsTypeMarkup => 'ترميز النص';

  @override
  String get commentsTypeDrawings => 'الرسومات';

  @override
  String get commentsTypeStamps => 'الأختام';

  @override
  String get commentsTypeOther => 'جميع الأنواع';

  @override
  String get commentsSortNewest => 'الأحدث';

  @override
  String get commentsSortAuthor => 'المؤلف';

  @override
  String get commentsSortOther => 'ترتيب الصفحات';

  @override
  String get commentsCertifiedNote =>
      'تسمح شهادة هذا المستند بالتعليقات: تبقى الشهادة صالحة معها.';

  @override
  String get commentsTruncated =>
      'يحتوي هذا الملف على تعليقات أكثر مما يعرضه Ferman.';

  @override
  String get commentsEmptyTitle => 'لا توجد تعليقات';

  @override
  String get commentsEmptyBody =>
      'اختر أداة من الأعلى، ثم أضف علامات على الصفحة.';

  @override
  String get commentsNoMatchTitle => 'لا توجد تعليقات مطابقة';

  @override
  String get commentsNoMatchBody => 'غيّر الحالة أو عوامل التصفية لرؤية غيرها.';

  @override
  String get commentsFootnote =>
      'تُحفظ التعليقات في ملف PDF. تنتقل الإشارات مع الملف، ولا يرسل Ferman إشعارات.';

  @override
  String get commentsExportSummary => 'تصدير الملخص…';

  @override
  String get commentsFlatten => 'تسطيح…';

  @override
  String get commentsHideAll => 'إخفاء الكل';

  @override
  String commentsHidden(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown تعليق مخفي',
      many: '$shown تعليقًا مخفيًا',
      few: '$shown تعليقات مخفية',
      two: 'تعليقان مخفيان',
      one: 'تعليق واحد مخفي',
    );
    return '$_temp0';
  }

  @override
  String get commentKindHighlight => 'تمييز';

  @override
  String get commentKindUnderline => 'تسطير';

  @override
  String get commentKindStrikeOut => 'يتوسطه خط';

  @override
  String get commentKindSquiggly => 'تسطير متموج';

  @override
  String get commentKindNote => 'ملاحظة';

  @override
  String get commentKindFreeText => 'نص';

  @override
  String get commentKindCallout => 'وسيلة شرح';

  @override
  String get commentKindInk => 'رسم';

  @override
  String get commentKindSquare => 'مستطيل';

  @override
  String get commentKindCircle => 'شكل بيضاوي';

  @override
  String get commentKindLine => 'خط';

  @override
  String get commentKindPolygon => 'مضلع';

  @override
  String get commentKindStamp => 'ختم';

  @override
  String get commentKindOther => 'تعليق';

  @override
  String commentStyleBar(String kind) {
    return 'نمط $kind';
  }

  @override
  String get commentStrokeWidth => 'سُمك الخط';

  @override
  String get commentOpacity => 'العتامة';

  @override
  String get commentOpen => 'فتح التعليق';

  @override
  String get commentDelete => 'حذف';

  @override
  String get commentMenu => 'تعليق';

  @override
  String get commentEditText => 'تحرير النص';

  @override
  String get commentMore => 'المزيد';

  @override
  String get commentCloseNote => 'إغلاق الملاحظة';

  @override
  String commentNoteFrom(String author) {
    return 'ملاحظة من $author';
  }

  @override
  String get commentReply => 'رد';

  @override
  String get commentResolve => 'حل';

  @override
  String get commentReopen => 'إعادة فتح';

  @override
  String get commentPeople => 'الأشخاص في هذا المستند';

  @override
  String commentQuote(String text) {
    return '«$text»';
  }

  @override
  String commentReplies(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown رد',
      many: '$shown ردًا',
      few: '$shown ردود',
      two: 'ردّان',
      one: 'رد واحد',
    );
    return '$_temp0';
  }

  @override
  String commentResolvedBy(String name, String time) {
    return 'حلّها $name · $time';
  }

  @override
  String get commentYesterday => 'أمس';

  @override
  String commentCardLabel(
    String author,
    String kind,
    String page,
    int resolved,
    int count,
    String shown,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      resolved,
      locale: localeName,
      other: '، محلولة',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '، $shown رد',
      many: '، $shown ردًا',
      few: '، $shown ردود',
      two: '، ردّان',
      one: '، رد واحد',
      zero: '',
    );
    return '$author، $kind في الصفحة $page$_temp0$_temp1';
  }

  @override
  String get commentStepAdd => 'إضافة تعليق';

  @override
  String get commentStepChange => 'تغيير التعليق';

  @override
  String get commentStepDelete => 'حذف التعليق';

  @override
  String get commentStepReply => 'الرد على التعليق';

  @override
  String get commentStepResolve => 'حل التعليق';

  @override
  String get commentStepReopen => 'إعادة فتح التعليق';

  @override
  String get commentDeletedToast => 'تم حذف التعليق';

  @override
  String get commentDeletedNote => 'مع ردوده.';

  @override
  String get commentNameTitle => 'اسمك في التعليقات';

  @override
  String get commentNameBody =>
      'يراه الآخرون ممن يفتحون ملف PDF هذا بجانب تعليقاتك. يمكنك تغييره من الإعدادات › عام، أو تركه فارغًا.';

  @override
  String get commentNameSave => 'متابعة';

  @override
  String get settingsCommenterName => 'اسمك للتعليقات';

  @override
  String get commentTextField => 'نص التعليق';

  @override
  String get commentSummaryFile => 'التعليقات.pdf';

  @override
  String get commentColumnPage => 'الصفحة';

  @override
  String get commentColumnType => 'النوع';

  @override
  String get commentColumnAuthor => 'المؤلف';

  @override
  String get commentColumnDate => 'التاريخ';

  @override
  String get commentColumnText => 'النص';

  @override
  String get commentColumnReplies => 'الردود';

  @override
  String get commentColumnStatus => 'الحالة';

  @override
  String get commentStatusOpen => 'مفتوح';

  @override
  String get commentStatusResolved => 'محلول';

  @override
  String jobSummaryRunningTitle(String name) {
    return 'جارٍ كتابة $name';
  }

  @override
  String jobSummaryDoneTitle(String name) {
    return 'تمت كتابة $name';
  }

  @override
  String jobSummaryFailedTitle(String name) {
    return 'تعذرت كتابة $name';
  }

  @override
  String get commentSummaryCsvFile => 'التعليقات.csv';

  @override
  String get summaryTitle => 'تصدير ملخص التعليقات';

  @override
  String get summaryFormat => 'التنسيق';

  @override
  String get summaryCsv => 'CSV';

  @override
  String get summaryLayout => 'التخطيط';

  @override
  String get summaryPageAndComments => 'الصفحة والتعليقات';

  @override
  String get summaryPageAndCommentsHint => 'علامات مرقمة بجانب كل صفحة';

  @override
  String get summaryCommentsOnly => 'التعليقات فقط';

  @override
  String get summaryCommentsOnlyHint => 'قائمة مجمّعة حسب الصفحة';

  @override
  String get summaryPageThenList => 'الصفحة ثم القائمة';

  @override
  String get summaryPageThenListHint => 'الصفحة كاملة تليها تعليقاتها';

  @override
  String summaryOpen(String count) {
    return 'التعليقات المفتوحة ($count)';
  }

  @override
  String get summaryReplies => 'الردود';

  @override
  String summaryResolved(String count) {
    return 'التعليقات المحلولة ($count)';
  }

  @override
  String get summaryEmptyPages => 'الصفحات التي بلا تعليقات';

  @override
  String get summarySortBy => 'الترتيب حسب';

  @override
  String get summarySortPage => 'ترتيب الصفحات';

  @override
  String get summaryPaper => 'الورق';

  @override
  String get summaryPreview => 'معاينة';

  @override
  String get summaryExport => 'تصدير الملخص…';

  @override
  String get jobSummaryPageUnsupported =>
      'رُسمت إحدى الصفحات بطريقة لا يستطيع Ferman تصويرها في ملخص بعد. يعمل تخطيط «التعليقات فقط» أو ملف CSV.';

  @override
  String flattenTitle(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هل تريد تسطيح $formatted تعليق في الصفحات؟',
      many: 'هل تريد تسطيح $formatted تعليقًا في الصفحات؟',
      few: 'هل تريد تسطيح $formatted تعليقات في الصفحات؟',
      two: 'هل تريد تسطيح تعليقين في الصفحات؟',
      one: 'هل تريد تسطيح تعليق واحد في الصفحات؟',
      zero: 'هل تريد تسطيح التعليقات في الصفحات؟',
    );
    return '$_temp0';
  }

  @override
  String get flattenBody =>
      'تصبح جزءًا من الصفحة. لن يتمكن أحد من تعديلها أو الرد عليها أو إخفائها أو إزالتها، في Ferman أو أي تطبيق آخر. تبدو حقول النماذج والتوقيعات كما كانت.';

  @override
  String flattenAll(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل التعليقات الـ$formatted',
      many: 'كل التعليقات الـ$formatted',
      few: 'كل التعليقات الـ$formatted',
      two: 'التعليقان كلاهما',
      one: 'التعليق الوحيد',
      zero: 'كل التعليقات',
    );
    return '$_temp0';
  }

  @override
  String flattenResolved(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التعليقات المحلولة الـ$formatted فقط',
      many: 'التعليقات المحلولة الـ$formatted فقط',
      few: 'التعليقات المحلولة الـ$formatted فقط',
      two: 'التعليقان المحلولان فقط',
      one: 'التعليق المحلول فقط',
      zero: 'لا توجد تعليقات محلولة',
    );
    return '$_temp0';
  }

  @override
  String get flattenKeepCopy => 'الاحتفاظ بنسخة مع التعليقات';

  @override
  String flattenKeepCopyHint(String name) {
    return 'تُحفظ باسم «$name» بجانب الأصل.';
  }

  @override
  String flattenCopyName(String stem) {
    return '$stem — مع التعليقات';
  }

  @override
  String flattenCopyNameNumbered(String stem, int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return '$stem — مع التعليقات $numberString';
  }

  @override
  String flattenAction(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تسطيح $formatted تعليق',
      many: 'تسطيح $formatted تعليقًا',
      few: 'تسطيح $formatted تعليقات',
      two: 'تسطيح تعليقين',
      one: 'تسطيح تعليق واحد',
      zero: 'تسطيح التعليقات',
    );
    return '$_temp0';
  }

  @override
  String get commentStepFlatten => 'تسطيح التعليقات';

  @override
  String jobFlatteningTitle(String name) {
    return 'جارٍ تسطيح التعليقات في $name';
  }

  @override
  String jobFlattenedTitle(String name) {
    return 'سُطّحت التعليقات في $name';
  }

  @override
  String jobFlattenFailedTitle(String name) {
    return 'تعذر تسطيح التعليقات في $name';
  }

  @override
  String get jobFlattenPageUnsupported =>
      'رُسمت إحدى الصفحات بطريقة لا يستطيع Ferman التسطيح فيها بعد. لم يتغير شيء.';

  @override
  String sidebarSearchComment(String text) {
    return 'تعليق: $text';
  }

  @override
  String get stampsTitle => 'الأختام';

  @override
  String get stampsSearch => 'البحث في الأختام';

  @override
  String get stampsNoMatch => 'لا توجد أختام تطابق بحثك';

  @override
  String get stampGroupStandard => 'قياسية';

  @override
  String get stampGroupNamed => 'بالاسم والتاريخ';

  @override
  String get stampGroupMine => 'أختامي';

  @override
  String get stampCreate => 'إنشاء ختم…';

  @override
  String get stampImport => 'استيراد…';

  @override
  String get stampExport => 'تصدير…';

  @override
  String get stampDelete => 'حذف';

  @override
  String get stampFileFilter => 'أختام Ferman';

  @override
  String get stampImportFailed => 'يتعذر استيراد هذا الختم';

  @override
  String get stampImportFailedBody => 'الملف ليس ختم Ferman أو أنه تالف.';

  @override
  String get stampExportFailed => 'تعذر تصدير الختم';

  @override
  String get stampsFull => 'قائمة «أختامي» ممتلئة. احذف أحدها أولاً.';

  @override
  String get createStampTitle => 'إنشاء ختم';

  @override
  String get createStampText => 'النص';

  @override
  String get createStampSecondLine => 'السطر الثاني';

  @override
  String get createStampMyName => 'اسمي';

  @override
  String get createStampDate => 'التاريخ';

  @override
  String get createStampTime => 'الوقت';

  @override
  String get createStampName => 'الاسم على الختم';

  @override
  String get createStampColour => 'اللون';

  @override
  String get stampToneSeal => 'أحمر الختم';

  @override
  String get stampToneInk => 'حبر';

  @override
  String get stampToneGreen => 'أخضر';

  @override
  String get stampToneGrey => 'رمادي';

  @override
  String get createStampCaps => 'لغة الأحرف الكبيرة';

  @override
  String get createStampLanguageTurkish => 'التركية (İNCELENDİ)';

  @override
  String get createStampLanguageEnglish => 'الإنجليزية';

  @override
  String get createStampLanguageGerman => 'الألمانية';

  @override
  String get createStampPreview => 'معاينة';

  @override
  String get createStampSavedNote => 'يُحفظ في «أختامي» على هذا الجهاز.';

  @override
  String get createStampSave => 'حفظ الختم';

  @override
  String get shapeRectangle => 'مستطيل';

  @override
  String get shapeEllipse => 'شكل بيضاوي';

  @override
  String get shapeArrow => 'سهم';

  @override
  String get shapeLine => 'خط';

  @override
  String get shapePolygon => 'مضلع';

  @override
  String get shapesKeepTool => 'إبقاء الأداة محددة';

  @override
  String get stepAddShape => 'إضافة شكل';

  @override
  String get stepAddStamp => 'إضافة ختم';

  @override
  String get placeStampHint =>
      'انقر على الصفحة لوضع الختم، أو اضغط Enter لوضعه في وسط الصفحة.';

  @override
  String get placeShapeHint =>
      'اسحب على الصفحة لرسم الشكل، أو اضغط Enter لوضعه في وسط الصفحة.';

  @override
  String get placePolygonHint =>
      'انقر على كل زاوية من زوايا المضلع، ثم اضغط Enter أو انقر على الزاوية الأولى.';

  @override
  String get linksTitle => 'الروابط';

  @override
  String get linksNote => 'يسأل Ferman قبل فتح رابط ويب من ملف PDF.';

  @override
  String get linksEmpty => 'لا توجد روابط في هذا المستند.';

  @override
  String get linksTruncated =>
      'يحتوي هذا المستند على روابط أكثر من أن تُعرض كلها.';

  @override
  String get linksSelectTextFirst => 'حدّد أولًا النص المراد ربطه';

  @override
  String get linksKindWeb => 'ويب';

  @override
  String get linksKindMail => 'بريد إلكتروني';

  @override
  String get linksKindPage => 'صفحة';

  @override
  String get linksKindScript => 'برنامج نصي، لا يُشغَّل';

  @override
  String get linksKindLaunch => 'برنامج، لا يُشغَّل';

  @override
  String get linksKindFile => 'ملف، لا يُفتح';

  @override
  String get linksKindAddress => 'عنوان، لا يُفتح';

  @override
  String get linksKindAction => 'إجراء غير معروف، يُحتفظ به';

  @override
  String get linksKindNothing => 'لا يفعل شيئًا';

  @override
  String linksPage(String page) {
    return 'الصفحة $page';
  }

  @override
  String get linksPageMissing => 'صفحة مفقودة';

  @override
  String linksMeta(String kind, String page) {
    return '$kind · الصفحة $page';
  }

  @override
  String linksMetaEditing(String kind, String page) {
    return '$kind · الصفحة $page · قيد التحرير';
  }

  @override
  String get linkAddTitle => 'إضافة رابط';

  @override
  String get linkEditTitle => 'تحرير الرابط';

  @override
  String get linkTo => 'الربط إلى';

  @override
  String get linkTypeFile => 'ملف';

  @override
  String get linkFieldWeb => 'عنوان الويب';

  @override
  String get linkFieldMail => 'عنوان البريد الإلكتروني';

  @override
  String get linkFieldPage => 'رقم الصفحة';

  @override
  String get linkAppearance => 'المظهر';

  @override
  String get linkLookNone => 'غير مرئي (يحتفظ النص بمظهره)';

  @override
  String get linkLookUnderline => 'تسطير';

  @override
  String get linkLookBox => 'إطار رفيع';

  @override
  String get linkRemove => 'إزالة الرابط';

  @override
  String get linkSave => 'حفظ الرابط';

  @override
  String get linkStepAdd => 'إضافة رابط';

  @override
  String get linkStepEdit => 'تحرير الرابط';

  @override
  String get linkStepRemove => 'إزالة الرابط';

  @override
  String get linkErrorWeb => 'اكتب عنوان ويب يبدأ بـ http:// أو https://.';

  @override
  String get linkErrorMail => 'اكتب عنوان بريد إلكتروني مثل name@example.com.';

  @override
  String get linkFailedTitle => 'تعذّر تغيير الرابط';

  @override
  String get linkOpenWebTitle => 'هل تريد فتح عنوان الويب هذا؟';

  @override
  String get linkOpenMailTitle => 'هل تريد مراسلة هذا العنوان؟';

  @override
  String get linkOpenDescription =>
      'هذا الرابط من المستند، ويُفتح في تطبيقاتك أنت، فتأكد من أنك تثق بوجهته.';

  @override
  String get linkOpenAction => 'فتح الرابط';

  @override
  String get linkOpenFailed => 'تعذّر فتح الرابط';

  @override
  String get linkBrokenTitle => 'هذا الرابط لا يؤدي إلى أي مكان';

  @override
  String get linkRefusedTitle => 'لم يتبع Ferman هذا الرابط';

  @override
  String get linkRefusedScript =>
      'كان سيشغّل برنامجًا نصيًا، ولا يشغّل Ferman البرامج النصية للمستندات.';

  @override
  String linkRefusedLaunch(String target) {
    return 'كان سيشغّل $target، ولا يشغّل Ferman البرامج للمستندات أبدًا.';
  }

  @override
  String linkRefusedFile(String target) {
    return 'يشير إلى ملف آخر، $target، ولا يفتح Ferman الملفات من الروابط.';
  }

  @override
  String linkRefusedAddress(String target) {
    return 'لا يفتح Ferman هذا النوع من العناوين: $target';
  }

  @override
  String get linkRefusedAction =>
      'يؤدي إجراءً لا يعرفه Ferman، لذا يبقى في الملف ولا يُنفَّذ.';

  @override
  String linksBrokenMeta(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'معطّل: يحتوي هذا المستند على $pages صفحة',
      few: 'معطّل: يحتوي هذا المستند على $pages صفحات',
      two: 'معطّل: يحتوي هذا المستند على صفحتين ($pages)',
      one: 'معطّل: يحتوي هذا المستند على صفحة واحدة ($pages)',
    );
    return '$_temp0';
  }

  @override
  String linkErrorPage(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اكتب صفحة من 1 إلى $pages.',
      one: 'يحتوي هذا المستند على صفحة واحدة ($pages).',
    );
    return '$_temp0';
  }

  @override
  String get signPadMethod => 'طريقة التوقيع';

  @override
  String get signPadDraw => 'رسم';

  @override
  String get signPadType => 'كتابة';

  @override
  String get signPadImage => 'صورة';

  @override
  String get signPadArea =>
      'منطقة رسم التوقيع. ارسم بالفأرة أو لوحة اللمس أو القلم أو الإصبع.';

  @override
  String get signPadTypeName => 'اكتب اسمك';

  @override
  String get signPadNamePlaceholder => 'اسمك';

  @override
  String get signPadDrawHint => 'وقّع فوق الخط';

  @override
  String get signPadTypeHint => 'اكتب اسمك فوق الخط';

  @override
  String get signPadImageHint =>
      'اختر صورة أو مسحًا ضوئيًا لتوقيعك. يزيل Ferman الخلفية.';

  @override
  String get signPadChooseImage => 'اختيار صورة…';

  @override
  String get signPadInk => 'لون الحبر';

  @override
  String get signPadBlack => 'أسود';

  @override
  String get signPadBlue => 'أزرق';

  @override
  String get signPadClear => 'مسح';

  @override
  String get signPadSave => 'الحفظ على هذا الجهاز';

  @override
  String get signDialogTitle => 'إضافة توقيع';

  @override
  String get signDialogTitleInitials => 'إضافة الأحرف الأولى';

  @override
  String get signCreate => 'إنشاء';

  @override
  String get signKindSignature => 'توقيع';

  @override
  String get signKindInitials => 'الأحرف الأولى';

  @override
  String get signHandwriting => 'نمط خط اليد';

  @override
  String get signNoStyle =>
      'لا يستطيع أي نمط من أنماط خط اليد كتابة كل حروف هذا الاسم. ارسمه أو استخدم صورة بدلًا من ذلك.';

  @override
  String get signSavedNote => 'يُحفظ على هذا الجهاز فقط.';

  @override
  String get signMenuLabel => 'التواقيع المحفوظة';

  @override
  String get signMenuSignatures => 'التواقيع';

  @override
  String get signMenuAdd => 'إضافة توقيع…';

  @override
  String get signMenuCreate => 'إنشاء توقيع…';

  @override
  String get signMenuManage => 'إدارة التواقيع المحفوظة…';

  @override
  String get signDrawn => 'مرسوم';

  @override
  String get signDelete => 'حذف';

  @override
  String get signSaveFailed =>
      'تعذّر حفظ التوقيع على هذا الجهاز، لكنه ما زال جاهزًا للوضع.';

  @override
  String get signImageTooLarge =>
      'هذه الصورة كبيرة جدًا. اختر صورة أصغر من 6 ميغابايت.';

  @override
  String get signImageFilter => 'الصور';

  @override
  String get stepAddSignature => 'إضافة توقيع';

  @override
  String get stepAddInitials => 'إضافة الأحرف الأولى';

  @override
  String get placeSignatureHint =>
      'انقر على الصفحة أو على حقل توقيع لوضعه، أو اضغط Enter لوضعه في وسط الصفحة. اسحب زواياه لتغيير حجمه ومقبضه الدائري لتدويره، ثم اضغط Enter.';

  @override
  String get formPanelTitle => 'النموذج';

  @override
  String get formMore => 'المزيد: مسح النموذج وتصدير البيانات';

  @override
  String formRequiredProgress(String filled, String total) {
    return '$filled من $total من الحقول المطلوبة';
  }

  @override
  String formSummaryFields(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted حقل',
      many: '$formatted حقلًا',
      few: '$formatted حقول',
      two: 'حقلان',
      one: 'حقل واحد',
    );
    return '$_temp0';
  }

  @override
  String formRequiredLeft(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $formatted حقل مطلوب',
      many: 'بقي $formatted حقلًا مطلوبًا',
      few: 'بقيت $formatted حقول مطلوبة',
      two: 'بقي حقلان مطلوبان',
      one: 'بقي حقل مطلوب واحد',
    );
    return '$_temp0';
  }

  @override
  String get formAllRequiredFilled => 'تمت تعبئة كل الحقول المطلوبة';

  @override
  String formFieldOf(String current, String total) {
    return 'الحقل $current من $total';
  }

  @override
  String get formHighlight => 'تمييز الحقول';

  @override
  String get formShowOrder => 'إظهار ترتيب التنقل';

  @override
  String get formHideOrder => 'إخفاء ترتيب التنقل';

  @override
  String get formSignedTitle => 'نموذج موقَّع';

  @override
  String get formSignedKeeps => 'تسمح شهادته بالتعبئة، لذا تبقى صالحة.';

  @override
  String get formSignedBreaks => 'تعبئته ستُبطل توقيعه.';

  @override
  String get formFontNoticeTitle => 'أُضيفت محارف بخط IBM Plex';

  @override
  String formFontNoticeBody(String fonts) {
    return 'لا يحوي خط هذا النموذج بعض المحارف التي كتبتها، لذا أضاف Ferman الخط $fonts إلى المستند لأجلها.';
  }

  @override
  String get formDismiss => 'إغلاق';

  @override
  String get formRequired => 'مطلوب';

  @override
  String get formMarkedField => 'يتعذّر عرض بعض المحارف بخط هذا الحقل';

  @override
  String get formClear => 'مسح النموذج…';

  @override
  String get formFinish => 'إنهاء';

  @override
  String get formExportData => 'تصدير البيانات…';

  @override
  String get formBannerTitle => 'ملف PDF هذا نموذج قابل للتعبئة.';

  @override
  String formBannerBody(int count, String formatted, String required) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$formatted حقل، المطلوب منها $required. ينقلك مفتاح Tab إلى الحقل التالي.',
      many:
          '$formatted حقلًا، المطلوب منها $required. ينقلك مفتاح Tab إلى الحقل التالي.',
      few:
          '$formatted حقول، المطلوب منها $required. ينقلك مفتاح Tab إلى الحقل التالي.',
      two: 'حقلان، المطلوب منهما $required. ينقلك مفتاح Tab إلى الحقل التالي.',
      one: 'حقل واحد، المطلوب منه $required. ينقلك مفتاح Tab إلى الحقل التالي.',
    );
    return '$_temp0';
  }

  @override
  String get formBannerHide => 'إخفاء';

  @override
  String get fillBannerTitle => 'لا يحوي ملف PDF هذا حقول نماذج.';

  @override
  String get fillBannerBody =>
      'انقر على سطر أو مربع لتكتب، أو دع Ferman يجد الحقول.';

  @override
  String get fillFindFields => 'العثور على الحقول';

  @override
  String get formPreviousField => 'الحقل السابق';

  @override
  String get formNextField => 'الحقل التالي';

  @override
  String formNavField(String current, String total) {
    return 'الحقل $current من $total';
  }

  @override
  String formNavFields(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted حقل',
      many: '$formatted حقلًا',
      few: '$formatted حقول',
      two: 'حقلان',
      one: 'حقل واحد',
    );
    return '$_temp0';
  }

  @override
  String get formNavAllFilled => 'كل المطلوب مُعبّأ';

  @override
  String get formSignHere => 'وقّع هنا';

  @override
  String formErrorTooLong(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استخدم $formatted محرف على الأكثر.',
      many: 'استخدم $formatted محرفًا على الأكثر.',
      few: 'استخدم $formatted محارف على الأكثر.',
      two: 'استخدم محرفين على الأكثر.',
      one: 'استخدم محرفًا واحدًا على الأكثر.',
    );
    return '$_temp0';
  }

  @override
  String formErrorDate(String pattern) {
    return 'أدخل التاريخ بالصيغة $pattern.';
  }

  @override
  String get formErrorNumber => 'أدخل رقمًا.';

  @override
  String formErrorRange(String min, String max) {
    return 'أدخل رقمًا من $min إلى $max.';
  }

  @override
  String formErrorMin(String min) {
    return 'أدخل رقمًا لا يقل عن $min.';
  }

  @override
  String formErrorMax(String max) {
    return 'أدخل رقمًا لا يزيد على $max.';
  }

  @override
  String get formErrorRequired => 'مطلوب للإرسال.';

  @override
  String get formErrorSign => 'وقّع قبل الإنهاء.';

  @override
  String get formErrorChoose => 'اختر أحد الخيارات.';

  @override
  String get formChooseDate => 'اختر تاريخًا';

  @override
  String formDateFormat(String pattern) {
    return 'الصيغة $pattern · من النموذج';
  }

  @override
  String get formPreviousMonth => 'الشهر السابق';

  @override
  String get formNextMonth => 'الشهر التالي';

  @override
  String get formToday => 'اليوم';

  @override
  String formStepFill(String name) {
    return 'تعبئة «$name»';
  }

  @override
  String get formStepClear => 'مسح النموذج';

  @override
  String get formStepFinish => 'إنهاء النموذج';

  @override
  String get fillStepText => 'إضافة نص';

  @override
  String get fillStepMark => 'إضافة علامة';

  @override
  String get formXfaRemovedTitle => 'أُزيلت بيانات XFA من النموذج';

  @override
  String get formXfaRemovedBody =>
      'كانت القارئات التي تستخدم XFA ستعرض القيم القديمة. يبقى الأصل في الإصدار السابق من الملف.';

  @override
  String get formFinishTitle => 'إنهاء النموذج';

  @override
  String get formFinishBody =>
      'تمت تعبئة كل الحقول المطلوبة. اختر كيف يبقى النموذج، ثم احفظه.';

  @override
  String get formFinishFlatten => 'تسطيح الحقول';

  @override
  String get formFinishFlattenBody =>
      'تصبح جزءًا من الصفحة ولا يمكن تغييرها بعد ذلك.';

  @override
  String get formFinishKeep => 'إبقاء الحقول قابلة للتحرير';

  @override
  String get formFinishKeepBody => 'يمكن لأي شخص يفتح الملف تغيير القيم.';

  @override
  String get formFinishSave => 'حفظ';

  @override
  String get formFinishSaveAs => 'حفظ باسم…';

  @override
  String get formClearTitle => 'هل تريد مسح النموذج؟';

  @override
  String get formClearBody =>
      'تُزال كل القيم في هذا النموذج. تبقى التوقيعات. يمكنك التراجع عن ذلك.';

  @override
  String get formClearConfirm => 'مسح النموذج';

  @override
  String get formFontAskTitle => 'محارف غير موجودة في خط هذا الحقل';

  @override
  String get formFontAskBody =>
      'يمكن لـ Ferman رسمها بخط IBM Plex يُضاف إلى المستند، أو إبقاء خط الحقل وتركها.';

  @override
  String get formFontAskPlex => 'استخدام IBM Plex';

  @override
  String get formFontAskKeep => 'إبقاء خط الحقل';

  @override
  String get fillPanelTitle => 'تعبئة أي شيء';

  @override
  String get fillToolText => 'نص';

  @override
  String get fillToolCheck => 'علامة صح';

  @override
  String get fillToolCross => 'علامة خطأ';

  @override
  String get fillToolDot => 'نقطة';

  @override
  String get fillToolToday => 'تاريخ اليوم';

  @override
  String get fillToolSignature => 'توقيع';

  @override
  String get fillOptions => 'الخيارات';

  @override
  String get fillSnap => 'المحاذاة إلى الأسطر والمربعات';

  @override
  String get fillComb => 'محرف واحد في كل مربع';

  @override
  String get fillInk => 'الحبر';

  @override
  String get fillInkBlack => 'أسود';

  @override
  String get fillInkBlue => 'أزرق (#1A3170)';

  @override
  String get findNotSearchedComments => 'لم يُبحث في التعليقات.';

  @override
  String sidebarSearchFormField(String text) {
    return 'حقل نموذج: $text';
  }

  @override
  String jobCompressingTitle(String name) {
    return 'جارٍ ضغط $name';
  }

  @override
  String jobCompressedTitle(String name) {
    return 'ضُغط $name';
  }

  @override
  String jobCompressFailedTitle(String name) {
    return 'تعذر ضغط $name';
  }

  @override
  String get jobCompressNotSmaller =>
      'لا يمكن أن يصغر أكثر، لذا لم يُكتب شيء. يبقى الأصل كما هو.';

  @override
  String jobCompressedSizes(String before, String after) {
    return '$before ← $after';
  }

  @override
  String get printForbidden => 'لا يسمح المؤلف بالطباعة';

  @override
  String printSent(String name) {
    return 'أُرسل $name إلى الطابعة';
  }

  @override
  String printFailed(String name) {
    return 'تعذرت طباعة $name';
  }

  @override
  String printTitle(String name) {
    return 'طباعة “$name”';
  }

  @override
  String get printSystemDialog => 'استخدام نافذة النظام…';

  @override
  String get printAction => 'طباعة';

  @override
  String get printPrinter => 'الطابعة';

  @override
  String get printPrinterSystem => 'تُختار في نافذة النظام';

  @override
  String get printCopies => 'النسخ';

  @override
  String get printPages => 'الصفحات';

  @override
  String get printPagesAll => 'الكل';

  @override
  String get printLayout => 'التخطيط';

  @override
  String get printLayoutPages => 'الصفحات';

  @override
  String get printLayoutBooklet => 'كتيّب';

  @override
  String get printLayoutPoster => 'ملصق';

  @override
  String get printBothSides => 'على الوجهين';

  @override
  String get printLongEdge => 'الحافة الطويلة';

  @override
  String get printShortEdge => 'الحافة القصيرة';

  @override
  String get printOneSide => 'وجه واحد';

  @override
  String get printScale => 'المقياس';

  @override
  String get printScaleFit => 'ملاءمة المساحة القابلة للطباعة';

  @override
  String get printScaleActual => 'الحجم الفعلي (100٪)';

  @override
  String get printScaleCustom => 'مخصص…';

  @override
  String get printInclude => 'تضمين';

  @override
  String printComments(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التعليقات والأختام ($n)',
    );
    return '$_temp0';
  }

  @override
  String get printFormFields => 'محتوى حقول النموذج';

  @override
  String get printHiddenLayers => 'الطبقات المخفية';

  @override
  String get printPreviousSheet => 'الورقة السابقة';

  @override
  String get printNextSheet => 'الورقة التالية';

  @override
  String printSheetOf(String sheet, String sheets, String paper) {
    return 'الورقة $sheet من $sheets · $paper';
  }

  @override
  String compressFileName(String name) {
    return '$name، مضغوط';
  }

  @override
  String get compressTitle => 'ضغط';

  @override
  String get compressPreset => 'الإعداد المسبق';

  @override
  String get compressHighQuality => 'جودة عالية';

  @override
  String get compressBalanced => 'متوازن';

  @override
  String get compressSmallest => 'الأصغر';

  @override
  String get compressHighQualityDescription => 'الصور بدقة 300 ppi، للطباعة.';

  @override
  String get compressBalancedDescription =>
      'الصور بدقة 150 ppi، للمشاركة والقراءة على الشاشة.';

  @override
  String get compressSmallestDescription =>
      'الصور بدقة 96 ppi، للبريد الإلكتروني. يبقى النص حادًا.';

  @override
  String get compressCustom => 'مخصص…';

  @override
  String get compressCustomDescription => 'اضبط دقة الصور والجودة وما يُزال.';

  @override
  String compressAbout(String size) {
    return '≈ $size';
  }

  @override
  String get compressNow => 'الآن';

  @override
  String get compressAfter => 'بعد';

  @override
  String compressEstimateSampled(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قُدّر من $n من الصور العيّنة. يظهر الحجم الدقيق بعد الحفظ.',
      one: 'قُدّر من صورة عيّنة واحدة. يظهر الحجم الدقيق بعد الحفظ.',
    );
    return '$_temp0';
  }

  @override
  String get compressEstimateExact =>
      'قيس على كل صورة. يظهر الحجم الدقيق بعد الحفظ.';

  @override
  String compressDoes(String preset) {
    return 'ما يفعله $preset';
  }

  @override
  String compressDoesImages(int count, String n, String ppi) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يعيد ضغط $n من الصور إلى $ppi ppi',
      one: 'يعيد ضغط صورة واحدة إلى $ppi ppi',
    );
    return '$_temp0';
  }

  @override
  String compressDoesFonts(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يدمج $n من نسخ الخطوط المكررة',
      one: 'يدمج نسخة خط مكررة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get compressDoesUnused =>
      'يزيل الكائنات غير المستخدمة والصور المصغّرة';

  @override
  String compressDoesLeft(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يترك $n من الصور كما هي: لا يستطيع Ferman إعادة ضغطها',
      one: 'يترك صورة واحدة كما هي: لا يستطيع Ferman إعادة ضغطها',
    );
    return '$_temp0';
  }

  @override
  String get compressDoesKeeps =>
      'يحتفظ بالنص والروابط والإشارات المرجعية والنماذج';

  @override
  String get compressSignedTitle => 'هذا المستند موقّع';

  @override
  String get compressSignedBody =>
      'لا تحتوي النسخة المضغوطة على تواقيع. يبقى الأصل الموقّع كما هو.';

  @override
  String get compressAction => 'ضغط وحفظ باسم…';

  @override
  String saveAsCommentsOff(String name) {
    return 'يُحفظ الملف نسخةً من دونها؛ ويبقى $name مفتوحًا بتعليقاته.';
  }

  @override
  String get saveAsHistoryOn =>
      'يُكتب الملف من جديد، من دون المراجعات السابقة أو الصفحات المحذوفة. تفقد التواقيع صلاحيتها.';

  @override
  String get saveAsHistoryOff =>
      'تبقى الصفحات المحذوفة والنص السابق في الملف ويمكن استعادتها منه.';

  @override
  String get versionTitle => 'سجل الإصدارات';

  @override
  String versionCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n إصدار',
      few: '$n إصدارات',
      two: 'إصداران',
      one: 'إصدار واحد',
      zero: 'لا إصدارات',
    );
    return '$_temp0';
  }

  @override
  String get versionList => 'الإصدارات';

  @override
  String get versionNone => 'لا إصدارات بعد. يحتفظ كل حفظ بإصدار.';

  @override
  String get versionKept =>
      'تُحفظ لمدة 30 يومًا على هذا الجهاز. غيّر ذلك من الإعدادات › التحرير.';

  @override
  String get versionNow => 'الآن';

  @override
  String get versionUnsaved => 'غير محفوظ';

  @override
  String versionNowDetail(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n من التعديلات منذ آخر حفظ',
      one: 'تعديل واحد منذ آخر حفظ',
      zero: 'تغييرات منذ آخر حفظ',
    );
    return '$_temp0';
  }

  @override
  String get versionOpened => 'فُتح';

  @override
  String get versionOpenedDetail => 'الملف كما فُتح';

  @override
  String get versionSaved => 'حُفظ';

  @override
  String get versionSigned => 'وُقّع';

  @override
  String get versionUnsavedWork => 'عمل غير محفوظ';

  @override
  String get versionRestored => 'استُعيد';

  @override
  String versionEdits(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n من التعديلات',
      one: 'تعديل واحد',
    );
    return '$_temp0';
  }

  @override
  String versionEditsNamed(int count, String n, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n من التعديلات · $names',
      one: 'تعديل واحد · $names',
    );
    return '$_temp0';
  }

  @override
  String versionViewing(String time) {
    return 'تعرض الإصدار من $time.';
  }

  @override
  String get versionReadOnly => 'للقراءة فقط. لم يتغيّر مستندك الحالي.';

  @override
  String get versionBack => 'العودة إلى الحالي';

  @override
  String get versionRestoreThis => 'استعادة هذا الإصدار…';

  @override
  String get versionRestoreShort => 'استعادة…';

  @override
  String get versionCompare => 'مقارنة بالحالي';

  @override
  String versionRestoreTitle(String time) {
    return 'هل تريد استعادة الإصدار من $time؟';
  }

  @override
  String get versionRestoreBody =>
      'يُحفظ ملفك الحالي، مع أي تعديلات غير محفوظة، كإصدار أولًا، فلا يضيع شيء.';

  @override
  String get versionRestore => 'استعادة';

  @override
  String get commandPalette => 'لوحة الأوامر';

  @override
  String get commandShowShortcuts => 'عرض اختصارات لوحة المفاتيح';

  @override
  String get commandSaveCopy => 'حفظ نسخة';

  @override
  String get commandDocumentProperties => 'خصائص المستند';

  @override
  String get commandNextDocument => 'المستند التالي';

  @override
  String commandShowDocument(String number) {
    return 'عرض المستند $number';
  }

  @override
  String get commandGoToPage => 'الانتقال إلى صفحة';

  @override
  String get commandReadingMode => 'وضع القراءة';

  @override
  String get commandInsertFromFile => 'إدراج من ملف';

  @override
  String get commandDeletePages => 'حذف الصفحات';

  @override
  String get commandSelectAllPages => 'تحديد كل الصفحات';

  @override
  String get commandMovePagesUp => 'نقل الصفحات لأعلى';

  @override
  String get commandMovePagesDown => 'نقل الصفحات لأسفل';

  @override
  String get commandWindowMenu => 'قائمة النافذة';

  @override
  String get commandCloseWindow => 'إغلاق النافذة';

  @override
  String get commandQuit => 'إنهاء Ferman';

  @override
  String get palettePlaceholder => 'ابحث في الأوامر والصفحات والنص';

  @override
  String paletteEmpty(String query) {
    return 'لا توجد أوامر تطابق “$query”. اضغط Enter للبحث في المستند بدلًا من ذلك.';
  }

  @override
  String paletteEmptyNoDocument(String query) {
    return 'لا توجد أوامر تطابق “$query”.';
  }

  @override
  String get paletteCommands => 'الأوامر';

  @override
  String get paletteRecentFiles => 'الملفات الأخيرة';

  @override
  String get paletteMove => 'تنقّل';

  @override
  String get paletteRun => 'تشغيل';

  @override
  String get shortcutsSheetSearch => 'البحث في الاختصارات';

  @override
  String get shortcutsSheetNote =>
      'غيّر الاختصارات من الإعدادات › اختصارات لوحة المفاتيح.';

  @override
  String get shortcutsChanged => 'مُغيَّر';

  @override
  String shortcutsNoMatch(String query) {
    return 'لا توجد اختصارات تطابق “$query”.';
  }

  @override
  String get shortcutsGroupGeneral => 'عام';

  @override
  String get shortcutsGroupNavigate => 'التنقل';

  @override
  String get shortcutsGroupWindow => 'النافذة';

  @override
  String get shortcutsPaneSearch => 'ابحث عن أمر أو اضغط المفاتيح';

  @override
  String get shortcutsPreset => 'الإعداد المسبق';

  @override
  String get shortcutsPresetFerman => 'Ferman (افتراضي)';

  @override
  String get shortcutsPresetAcrobat => 'مثل Acrobat';

  @override
  String get shortcutsPresetPreview => 'مثل المعاينة';

  @override
  String get shortcutsRecording => 'اضغط الاختصار الجديد…';

  @override
  String shortcutsTaken(String keys, String command, String current) {
    return '$keys مستخدم بالفعل لـ“$command”. اضغط Enter لإعادة تعيينه، أو Esc للإبقاء على $current.';
  }

  @override
  String shortcutsTakenNone(String keys, String command) {
    return '$keys مستخدم بالفعل لـ“$command”. اضغط Enter لإعادة تعيينه، أو Esc للإبقاء دون اختصار.';
  }

  @override
  String shortcutsReserved(String keys) {
    return '$keys محجوز للنظام. اضغط مفاتيح أخرى، أو Esc للإلغاء.';
  }

  @override
  String get shortcutsNone => 'بلا اختصار';

  @override
  String shortcutsChange(String command) {
    return 'تغيير اختصار $command';
  }

  @override
  String get shortcutsReset => 'استعادة الاختصار الافتراضي';
}
