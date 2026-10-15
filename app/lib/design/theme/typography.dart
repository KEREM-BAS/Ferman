import 'package:ferman/design/tokens.g.dart';
import 'package:flutter/widgets.dart';

/// The writing system the UI fonts are chosen for, from the UI locale
/// (ARCHITECTURE §11.5, ADR 0013).
enum FermanScript {
  /// Latin, Cyrillic, Greek and Devanagari UIs (en, tr, de, ru, hi, …): the
  /// design's `--font-ui` stack as it is. Plex Sans stays first for Hindi
  /// too, because Plex Sans Devanagari draws Latin marks badly
  /// (`test/goldens/script_coverage_golden_test.dart`).
  standard,

  /// Arabic and Persian (ar, fa): the design's `--font-ui` stack as it is,
  /// as the design's Arabic boards (a12-2a, a12-2c) use it. IBM Plex Sans
  /// stays first because Plex Sans Arabic carries `I`, `s` and combining
  /// marks but not `İ`, `ş` or `ế`, so with it first Turkish and Vietnamese
  /// letters are built from base plus mark with misplaced marks
  /// (`test/goldens/script_coverage_golden_test.dart`).
  arabic,

  /// Hebrew (he): the `--font-ui` stack as it is, for the same reason as
  /// [arabic].
  hebrew,

  /// Japanese (ja): IBM Plex Sans for Latin, then the system Japanese font.
  japanese,

  /// Korean (ko): IBM Plex Sans for Latin, then the system Korean font.
  korean,

  /// Simplified Chinese (zh, zh-Hans, zh-CN, zh-SG): IBM Plex Sans for
  /// Latin, then the system Simplified Chinese font.
  simplifiedChinese,

  /// Traditional Chinese (zh-Hant, zh-TW, zh-HK, zh-MO): IBM Plex Sans for
  /// Latin, then the system Traditional Chinese font.
  traditionalChinese;

  /// The script of the UI language [locale]; [standard] when it is null.
  static FermanScript forLocale(Locale? locale) {
    if (locale == null) return standard;
    switch (locale.languageCode) {
      case 'ar' || 'fa':
        return arabic;
      case 'he' || 'iw':
        return hebrew;
      case 'ja':
        return japanese;
      case 'ko':
        return korean;
      case 'zh':
        final script = locale.scriptCode;
        if (script == 'Hant') return traditionalChinese;
        if (script == 'Hans') return simplifiedChinese;
        return switch (locale.countryCode) {
          'TW' || 'HK' || 'MO' => traditionalChinese,
          _ => simplifiedChinese,
        };
    }
    return standard;
  }

  /// Whether this is Japanese, Korean or Chinese, which take the design's
  /// CJK type overrides ([FermanTypeRoleTokens.cjk]).
  bool get isCjk => switch (this) {
    japanese || korean || simplifiedChinese || traditionalChinese => true,
    standard || arabic || hebrew => false,
  };
}

/// Font family names that are not in the design tokens.
///
/// The bundled families come from `app/pubspec.yaml`; the system CJK
/// families are the ones ADR 0013 names per system (macOS, Windows, Linux),
/// in that order. A family that is not installed is skipped by Flutter, so
/// every list names all three systems. Naming them, instead of leaving the
/// choice to the engine, also picks families with real bold faces, which
/// is as close as Flutter gets to the design's `font-synthesis: none` for
/// CJK: Flutter has no switch that turns synthetic bold off.
abstract final class FermanFontFamilies {
  /// IBM Plex Sans Hebrew, bundled (Q08); `--font-ui` names it as a
  /// fallback (ARCHITECTURE §11.5).
  static const String plexSansHebrew = 'IBM Plex Sans Hebrew';

  /// Japanese system fonts: Hiragino Sans, Yu Gothic UI, Noto Sans CJK JP.
  static const List<String> japanese = [
    'Hiragino Sans',
    'Yu Gothic UI',
    'Noto Sans CJK JP',
  ];

  /// Korean system fonts: Apple SD Gothic Neo, Malgun Gothic, Noto Sans CJK
  /// KR.
  static const List<String> korean = [
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Noto Sans CJK KR',
  ];

  /// Simplified Chinese system fonts: PingFang SC, Microsoft YaHei UI, Noto
  /// Sans CJK SC.
  static const List<String> simplifiedChinese = [
    'PingFang SC',
    'Microsoft YaHei UI',
    'Noto Sans CJK SC',
  ];

  /// Traditional Chinese system fonts: PingFang TC, Microsoft JhengHei UI,
  /// Noto Sans CJK TC.
  static const List<String> traditionalChinese = [
    'PingFang TC',
    'Microsoft JhengHei UI',
    'Noto Sans CJK TC',
  ];

  /// The system families for [script]; empty unless it is CJK.
  static List<String> systemFor(FermanScript script) => switch (script) {
    FermanScript.japanese => japanese,
    FermanScript.korean => korean,
    FermanScript.simplifiedChinese => simplifiedChinese,
    FermanScript.traditionalChinese => traditionalChinese,
    FermanScript.standard ||
    FermanScript.arabic ||
    FermanScript.hebrew => const [],
  };

  /// The UI font chain for [script]: the first family, then the fallbacks.
  ///
  /// - [FermanScript.standard], [FermanScript.arabic] and
  ///   [FermanScript.hebrew]: `--font-ui` (IBM Plex Sans, then Plex Sans
  ///   Arabic, Hebrew and Devanagari).
  /// - CJK: Plex Sans for Latin, the system families for the language, then
  ///   the rest of `--font-ui`.
  ///
  /// No script font comes first: the Arabic, Hebrew and Devanagari fonts
  /// lack Turkish and Vietnamese letters (ADR 0013, ARCHITECTURE §11.5).
  static List<String> uiChain(FermanScript script) {
    const ui = FermanTypeTokens.fontUi;
    final sans = ui.family!;
    final rest = ui.fallback;
    return switch (script) {
      FermanScript.standard ||
      FermanScript.arabic ||
      FermanScript.hebrew => [sans, ...rest],
      FermanScript.japanese ||
      FermanScript.korean ||
      FermanScript.simplifiedChinese ||
      FermanScript.traditionalChinese => [sans, ...systemFor(script), ...rest],
    };
  }
}

/// The ten type roles of the design (`--type-*`), resolved for one UI
/// locale.
///
/// - Japanese, Korean and Chinese take [FermanTypeRoleTokens.cjk] (taller
///   leading on body, body strong, caption, label and panel title); every
///   other language takes [FermanTypeRoleTokens.standard].
/// - Every style carries [locale], so Han characters take the right
///   regional forms (Traditional Chinese never shows Simplified forms,
///   ADR 0013) and shaping uses the language's rules.
/// - The UI roles use the font chain of [FermanFontFamilies.uiChain] for
///   the locale's [script]. The mono and wordmark roles keep their family
///   (IBM Plex Mono, IBM Plex Serif) and fall back to the same chain.
/// - No role is italic, and the CJK roles keep the design's weights; see
///   [FermanFontFamilies] for synthetic bold.
///
/// Colour is not part of a role: take it from the theme's colours.
@immutable
final class FermanTypography {
  /// Creates a set of roles. Use [FermanTypography.forLocale].
  const new({
    required this.locale,
    required this.script,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.dialogTitle,
    required this.headline,
    required this.label,
    required this.mono,
    required this.panelTitle,
    required this.prose,
    required this.wordmark,
  });

  /// The roles for the UI language [locale] (null: no locale, standard
  /// roles with the `--font-ui` chain).
  ///
  /// Results are cached per locale, so equal locales give the same object.
  factory forLocale(Locale? locale) => _cache[locale] ??=
      FermanTypography._resolve(locale, FermanScript.forLocale(locale));

  factory _resolve(Locale? locale, FermanScript script) {
    final roles = script.isCjk
        ? FermanTypeRoleTokens.cjk
        : FermanTypeRoleTokens.standard;
    final chain = FermanFontFamilies.uiChain(script);
    final uiFamily = FermanTypeTokens.fontUi.family;
    TextStyle adapt(TextStyle style) {
      if (style.fontFamily == uiFamily) {
        return style.copyWith(
          fontFamily: chain.first,
          fontFamilyFallback: chain.sublist(1),
          locale: locale,
        );
      }
      final own = style.fontFamilyFallback ?? const <String>[];
      return style.copyWith(
        fontFamilyFallback: [
          ...own,
          for (final family in chain)
            if (family != style.fontFamily && !own.contains(family)) family,
        ],
        locale: locale,
      );
    }

    return FermanTypography(
      locale: locale,
      script: script,
      body: adapt(roles.body),
      bodyStrong: adapt(roles.bodyStrong),
      caption: adapt(roles.caption),
      dialogTitle: adapt(roles.dialogTitle),
      headline: adapt(roles.headline),
      label: adapt(roles.label),
      mono: adapt(roles.mono),
      panelTitle: adapt(roles.panelTitle),
      prose: adapt(roles.prose),
      wordmark: adapt(roles.wordmark),
    );
  }

  static final Map<Locale?, FermanTypography> _cache = {};

  /// The roles without a locale: [FermanTypeRoleTokens.standard] with the
  /// `--font-ui` chain. The app's theme scope replaces them with the roles
  /// for the UI locale.
  static final FermanTypography standard = FermanTypography.forLocale(null);

  /// The UI locale every style carries, or null.
  final Locale? locale;

  /// The writing system the font chain was chosen for.
  final FermanScript script;

  /// `--type-body`: default UI text, buttons, inputs.
  final TextStyle body;

  /// `--type-body-strong`: emphasised UI text.
  final TextStyle bodyStrong;

  /// `--type-caption`: secondary text, tooltips, captions.
  final TextStyle caption;

  /// `--type-dialog-title`: dialog titles.
  final TextStyle dialogTitle;

  /// `--type-headline`: empty-state headline.
  final TextStyle headline;

  /// `--type-label`: section labels, badges, shortcut hints.
  final TextStyle label;

  /// `--type-mono`: technical details in IBM Plex Mono.
  final TextStyle mono;

  /// `--type-panel-title`: panel titles.
  final TextStyle panelTitle;

  /// `--type-prose`: dialog body, readable prose.
  final TextStyle prose;

  /// `--type-wordmark`: the Ferman wordmark in IBM Plex Serif.
  final TextStyle wordmark;

  /// Whether these are the CJK roles.
  bool get isCjk => script.isCjk;

  /// A copy with the given roles replaced.
  FermanTypography copyWith({
    Locale? locale,
    FermanScript? script,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? caption,
    TextStyle? dialogTitle,
    TextStyle? headline,
    TextStyle? label,
    TextStyle? mono,
    TextStyle? panelTitle,
    TextStyle? prose,
    TextStyle? wordmark,
  }) => FermanTypography(
    locale: locale ?? this.locale,
    script: script ?? this.script,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    caption: caption ?? this.caption,
    dialogTitle: dialogTitle ?? this.dialogTitle,
    headline: headline ?? this.headline,
    label: label ?? this.label,
    mono: mono ?? this.mono,
    panelTitle: panelTitle ?? this.panelTitle,
    prose: prose ?? this.prose,
    wordmark: wordmark ?? this.wordmark,
  );

  /// Interpolates between this set and [other] by [t]. Families, locale
  /// and script switch at t = 0.5, as [TextStyle.lerp] does.
  FermanTypography lerp(FermanTypography other, double t) {
    if (identical(this, other)) return this;
    TextStyle style(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    final first = t < 0.5;
    return FermanTypography(
      locale: first ? locale : other.locale,
      script: first ? script : other.script,
      body: style(body, other.body),
      bodyStrong: style(bodyStrong, other.bodyStrong),
      caption: style(caption, other.caption),
      dialogTitle: style(dialogTitle, other.dialogTitle),
      headline: style(headline, other.headline),
      label: style(label, other.label),
      mono: style(mono, other.mono),
      panelTitle: style(panelTitle, other.panelTitle),
      prose: style(prose, other.prose),
      wordmark: style(wordmark, other.wordmark),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FermanTypography &&
          other.locale == locale &&
          other.script == script &&
          other.body == body &&
          other.bodyStrong == bodyStrong &&
          other.caption == caption &&
          other.dialogTitle == dialogTitle &&
          other.headline == headline &&
          other.label == label &&
          other.mono == mono &&
          other.panelTitle == panelTitle &&
          other.prose == prose &&
          other.wordmark == wordmark;

  @override
  int get hashCode => Object.hash(
    locale,
    script,
    body,
    bodyStrong,
    caption,
    dialogTitle,
    headline,
    label,
    mono,
    panelTitle,
    prose,
    wordmark,
  );
}
