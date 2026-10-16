import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';

/// The app's settings: what Settings (a11-1) and first run (a1-1) let the
/// user choose in M1. Immutable; change it with [copyWith] through
/// `settingsProvider`.
///
/// Stored as versioned JSON by a `SettingsStore` ([toJson],
/// [AppSettings.fromJson]).
/// Values a newer app wrote that this one does not know are kept in
/// [unknown] and written back unchanged, so opening the same settings with
/// an older build never loses them.
@immutable
final class AppSettings {
  /// Settings with the defaults: follow the system for theme, language and
  /// region, onboarding not done.
  const new({
    this.themeMode = AppThemeMode.system,
    this.languageCode,
    this.regionCode,
    this.paperSize,
    this.lengthUnit,
    this.firstDayOfWeek,
    this.onboardingCompleted = false,
    this.unknown = const {},
    this.version = currentVersion,
  });

  /// Reads settings from their JSON form. Missing or unreadable values fall
  /// back to the defaults; keys this version does not know go to
  /// [unknown].
  factory fromJson(Map<String, Object?> json) {
    T? pick<T extends Enum>(List<T> values, Object? name) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    String? code(Object? value) =>
        value is String && value.isNotEmpty ? value : null;

    return AppSettings(
      themeMode: pick(AppThemeMode.values, json[_theme]) ?? AppThemeMode.system,
      languageCode: code(json[_language]),
      regionCode: code(json[_region]),
      paperSize: pick(PaperSize.values, json[_paperSize]),
      lengthUnit: pick(LengthUnit.values, json[_lengthUnit]),
      firstDayOfWeek: pick(FirstDayOfWeek.values, json[_firstDayOfWeek]),
      onboardingCompleted: json[_onboardingCompleted] == true,
      unknown: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!_known.contains(key)) key: value,
      },
      version: switch (json[_version]) {
        final int v when v > currentVersion => v,
        _ => currentVersion,
      },
    );
  }

  /// The format version this build writes.
  static const int currentVersion = 1;

  static const String _version = 'version';
  static const String _theme = 'theme';
  static const String _language = 'language';
  static const String _region = 'region';
  static const String _paperSize = 'paperSize';
  static const String _lengthUnit = 'lengthUnit';
  static const String _firstDayOfWeek = 'firstDayOfWeek';
  static const String _onboardingCompleted = 'onboardingCompleted';
  static const Set<String> _known = {
    _version,
    _theme,
    _language,
    _region,
    _paperSize,
    _lengthUnit,
    _firstDayOfWeek,
    _onboardingCompleted,
  };

  /// Settings → General → Theme.
  final AppThemeMode themeMode;

  /// The app language as a language code (`en`, `tr`, `ar`); null follows
  /// the system.
  final String? languageCode;

  /// The region for formats as a region code (`TR`, `US`); null takes the
  /// region of the operating system's locale ([Region.fromLocale]); the UI
  /// language never takes part (G34, a11-1b).
  final String? regionCode;

  /// The paper size; null is the region's default.
  final PaperSize? paperSize;

  /// The length unit; null is the region's default.
  final LengthUnit? lengthUnit;

  /// The first day of the week; null is the region's default.
  final FirstDayOfWeek? firstDayOfWeek;

  /// Whether first run (a1-1, a1-2b, a1-2c) has been completed.
  final bool onboardingCompleted;

  /// Keys from a newer settings file, kept as they were.
  final Map<String, Object?> unknown;

  /// The format version to write: [currentVersion], or the newer version of
  /// the file these settings were read from, so an older build never
  /// lowers it.
  final int version;

  /// The JSON form, with the format [version].
  Map<String, Object?> toJson() => {
    ...unknown,
    _version: version,
    _theme: themeMode.name,
    _language: ?languageCode,
    _region: ?regionCode,
    _paperSize: ?paperSize?.name,
    _lengthUnit: ?lengthUnit?.name,
    _firstDayOfWeek: ?firstDayOfWeek?.name,
    _onboardingCompleted: onboardingCompleted,
  };

  /// A copy with the given values. The nullable choices take a function so
  /// they can be set back to null ("follow the system", "region default").
  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? Function()? languageCode,
    String? Function()? regionCode,
    PaperSize? Function()? paperSize,
    LengthUnit? Function()? lengthUnit,
    FirstDayOfWeek? Function()? firstDayOfWeek,
    bool? onboardingCompleted,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode == null ? this.languageCode : languageCode(),
    regionCode: regionCode == null ? this.regionCode : regionCode(),
    paperSize: paperSize == null ? this.paperSize : paperSize(),
    lengthUnit: lengthUnit == null ? this.lengthUnit : lengthUnit(),
    firstDayOfWeek: firstDayOfWeek == null
        ? this.firstDayOfWeek
        : firstDayOfWeek(),
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    unknown: unknown,
    version: version,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.languageCode == languageCode &&
      other.regionCode == regionCode &&
      other.paperSize == paperSize &&
      other.lengthUnit == lengthUnit &&
      other.firstDayOfWeek == firstDayOfWeek &&
      other.onboardingCompleted == onboardingCompleted &&
      other.version == version &&
      mapEquals(other.unknown, unknown);

  @override
  int get hashCode => Object.hash(
    themeMode,
    languageCode,
    regionCode,
    paperSize,
    lengthUnit,
    firstDayOfWeek,
    onboardingCompleted,
    version,
    Object.hashAllUnordered(unknown.keys),
  );

  @override
  String toString() => 'AppSettings(${toJson()})';
}
