// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Ferman';

  @override
  String get startPlaceholderTitle => 'Drop a PDF here';

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
}
