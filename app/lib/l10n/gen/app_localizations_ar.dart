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
}
