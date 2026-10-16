import 'dart:ui' show Locale, TextDirection;

/// The 21 interface languages of the design, in the order of the a1-1
/// language picker (`01 First run and files.dc.html`, `LANGS`).
///
/// Each language has its own name in its own script ([endonym]) and its
/// English name ([englishName]), as a1-1 draws them side by side: both are
/// fixed data, the same in every UI language, like the design's
/// `lang="en"` column. English, Turkish and Arabic are [translated]; the
/// others stay selectable with the "Not translated yet" state (G20), and
/// the UI then shows English until volunteers translate it (ADR 0014).
///
/// The stored setting (`AppSettings.languageCode`) is the language's [tag].
enum AppLanguage {
  /// English, the source language.
  english('en', 'English', 'English', translated: true),

  /// Turkish, complete.
  turkish('tr', 'Türkçe', 'Turkish', translated: true),

  /// German.
  german('de', 'Deutsch', 'German'),

  /// French.
  french('fr', 'Français', 'French'),

  /// Spanish.
  spanish('es', 'Español', 'Spanish'),

  /// Portuguese as written in Brazil.
  portugueseBrazil('pt-BR', 'Português (Brasil)', 'Portuguese, Brazil'),

  /// Italian.
  italian('it', 'Italiano', 'Italian'),

  /// Dutch.
  dutch('nl', 'Nederlands', 'Dutch'),

  /// Polish.
  polish('pl', 'Polski', 'Polish'),

  /// Russian.
  russian('ru', 'Русский', 'Russian'),

  /// Ukrainian.
  ukrainian('uk', 'Українська', 'Ukrainian'),

  /// Arabic, right to left.
  arabic('ar', 'العربية', 'Arabic', translated: true, rightToLeft: true),

  /// Persian, right to left.
  persian('fa', 'فارسی', 'Persian', rightToLeft: true),

  /// Hebrew, right to left.
  hebrew('he', 'עברית', 'Hebrew', rightToLeft: true),

  /// Hindi.
  hindi('hi', 'हिन्दी', 'Hindi'),

  /// Japanese.
  japanese('ja', '日本語', 'Japanese'),

  /// Korean.
  korean('ko', '한국어', 'Korean'),

  /// Chinese in simplified characters.
  chineseSimplified('zh-Hans', '简体中文', 'Chinese, Simplified'),

  /// Chinese in traditional characters.
  chineseTraditional('zh-Hant', '繁體中文', 'Chinese, Traditional'),

  /// Indonesian.
  indonesian('id', 'Bahasa Indonesia', 'Indonesian'),

  /// Vietnamese.
  vietnamese('vi', 'Tiếng Việt', 'Vietnamese');

  new(
    this.tag,
    this.endonym,
    this.englishName, {
    this.translated = false,
    this.rightToLeft = false,
  });

  /// The BCP 47 tag stored in the settings: `en`, `pt-BR`, `zh-Hant`.
  final String tag;

  /// The language's own name in its own script, as a1-1 draws it.
  final String endonym;

  /// The language's English name, as a1-1 draws it beside the endonym.
  final String englishName;

  /// Whether the app has this language's translation. Untranslated
  /// languages fall back to English (G20).
  final bool translated;

  /// Whether the language is written right to left.
  final bool rightToLeft;

  /// The direction of the language's script: for its [endonym], and the
  /// direction of the whole UI while it is the app language, even when its
  /// strings fall back to English (Persian and Hebrew mirror the UI at once,
  /// G20, ADR 0014).
  TextDirection get textDirection =>
      rightToLeft ? TextDirection.rtl : TextDirection.ltr;

  /// Whether the UI wraps each of its strings in a left-to-right isolate
  /// while this is the app language: a right-to-left language without a
  /// translation (Persian and Hebrew today). Its UI mirrors, but its strings
  /// are English, which would reorder in a right-to-left paragraph ("1 of
  /// 2" as "of 2 1"); `FermanApp` then installs
  /// `IsolatedFallbackLocalizations` (G93).
  bool get isolatesFallbackStrings => rightToLeft && !translated;

  /// The language as a [Locale], with its script or region subtag.
  Locale get locale {
    final [language, ...rest] = tag.split('-');
    final subtag = rest.isEmpty ? null : rest.first;
    return subtag != null && subtag.length == 4
        ? Locale.fromSubtags(languageCode: language, scriptCode: subtag)
        : Locale.fromSubtags(languageCode: language, countryCode: subtag);
  }

  /// The locale of the UI's strings for this language: its own when it is
  /// [translated], English otherwise (G20, ADR 0014). The UI's direction
  /// follows [textDirection], not this locale.
  Locale get uiLocale => translated ? locale : english.locale;

  /// The language stored as [tag] (`AppSettings.languageCode`), or null for
  /// a tag that names none of the 21.
  static AppLanguage? fromTag(String? tag) {
    if (tag == null) return null;
    for (final language in values) {
      if (language.tag == tag) return language;
    }
    return null;
  }

  /// The language of the operating system's [locale], or null when it is
  /// none of the 21.
  ///
  /// Chinese takes the traditional characters for the script `Hant` and
  /// for Taiwan, Hong Kong and Macao, the simplified ones otherwise;
  /// Portuguese of any region is Português (Brasil), the one Portuguese the
  /// design offers. The legacy codes `iw` and `in` are Hebrew and
  /// Indonesian.
  static AppLanguage? forLocale(Locale locale) {
    final language = switch (locale.languageCode) {
      'iw' => 'he',
      'in' => 'id',
      final code => code,
    };
    if (language == 'zh') {
      final traditional =
          locale.scriptCode == 'Hant' ||
          (locale.scriptCode == null &&
              const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
      return traditional ? chineseTraditional : chineseSimplified;
    }
    if (language == 'pt') return portugueseBrazil;
    for (final candidate in values) {
      if (candidate.tag == language) return candidate;
    }
    return null;
  }
}
