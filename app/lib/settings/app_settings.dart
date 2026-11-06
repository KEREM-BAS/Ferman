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
    this.reopenDocuments = true,
    this.lastDocuments = const [],
    this.askDefaultApp = true,
    this.pageLook = PageLook.paper,
    this.pageLayout = NewDocumentLayout.scroll,
    this.zoom = NewDocumentZoom.fitWidth,
    this.missingGlyphs = MissingGlyphPolicy.similar,
    this.recoveryCopies = true,
    this.reflow = true,
    this.markEdited = true,
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
      reopenDocuments: json[_reopenDocuments] != false,
      lastDocuments: switch (json[_lastDocuments]) {
        final List<Object?> paths => [
          for (final path in paths)
            if (path is String && path.isNotEmpty) path,
        ],
        _ => const [],
      },
      askDefaultApp: json[_askDefaultApp] != false,
      pageLook: pick(PageLook.values, json[_pageLook]) ?? PageLook.paper,
      pageLayout:
          pick(NewDocumentLayout.values, json[_pageLayout]) ??
          NewDocumentLayout.scroll,
      zoom:
          pick(NewDocumentZoom.values, json[_zoom]) ?? NewDocumentZoom.fitWidth,
      missingGlyphs:
          pick(MissingGlyphPolicy.values, json[_missingGlyphs]) ??
          MissingGlyphPolicy.similar,
      recoveryCopies: json[_recoveryCopies] != false,
      reflow: json[_reflow] != false,
      markEdited: json[_markEdited] != false,
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
  static const String _reopenDocuments = 'reopenDocuments';
  static const String _lastDocuments = 'lastDocuments';
  static const String _askDefaultApp = 'askDefaultApp';
  static const String _pageLook = 'pageLook';
  static const String _pageLayout = 'pageLayout';
  static const String _zoom = 'zoom';
  static const String _missingGlyphs = 'missingGlyphs';
  static const String _recoveryCopies = 'recoveryCopies';
  static const String _reflow = 'reflow';
  static const String _markEdited = 'markEdited';
  static const Set<String> _known = {
    _version,
    _theme,
    _language,
    _region,
    _paperSize,
    _lengthUnit,
    _firstDayOfWeek,
    _onboardingCompleted,
    _reopenDocuments,
    _lastDocuments,
    _askDefaultApp,
    _pageLook,
    _pageLayout,
    _zoom,
    _missingGlyphs,
    _recoveryCopies,
    _reflow,
    _markEdited,
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

  /// Settings → General → Reopen documents from last time (B079): the
  /// files of [lastDocuments] open again at start-up.
  final bool reopenDocuments;

  /// The paths of the files open when the app last ran, in tab order;
  /// kept only while [reopenDocuments] is on.
  final List<String> lastDocuments;

  /// Whether the start screen asks to make Ferman the app that opens PDF
  /// files (a1-3, B080); off once it was answered with Use Ferman or with
  /// Don't ask again.
  final bool askDefaultApp;

  /// Settings → General → PDF pages in dark theme (B078): Paper white, or
  /// Dimmed through the page filter; the light theme never dims.
  final PageLook pageLook;

  /// Settings → General → Page layout of documents as they open (B035).
  final NewDocumentLayout pageLayout;

  /// Settings → General → Zoom of documents as they open (B034).
  final NewDocumentZoom zoom;

  /// Settings → Editing → When a font is missing a character (a11-1c,
  /// G36): what missing-glyph step 3 does.
  final MissingGlyphPolicy missingGlyphs;

  /// Settings → Editing → Save a recovery copy every minute (a11-1c).
  final bool recoveryCopies;

  /// Settings → Editing → Let paragraphs reflow inside their frame while
  /// typing (a11-1c). Off, only a line feed ends a line.
  final bool reflow;

  /// Edit row and Settings → Editing → Mark edited text (a11-1c, f3): the
  /// marks on the canvas, which never reach the file.
  final bool markEdited;

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
    _reopenDocuments: reopenDocuments,
    _lastDocuments: lastDocuments,
    _askDefaultApp: askDefaultApp,
    _pageLook: pageLook.name,
    _pageLayout: pageLayout.name,
    _zoom: zoom.name,
    _missingGlyphs: missingGlyphs.name,
    _recoveryCopies: recoveryCopies,
    _reflow: reflow,
    _markEdited: markEdited,
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
    bool? reopenDocuments,
    List<String>? lastDocuments,
    bool? askDefaultApp,
    PageLook? pageLook,
    NewDocumentLayout? pageLayout,
    NewDocumentZoom? zoom,
    MissingGlyphPolicy? missingGlyphs,
    bool? recoveryCopies,
    bool? reflow,
    bool? markEdited,
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
    reopenDocuments: reopenDocuments ?? this.reopenDocuments,
    lastDocuments: lastDocuments ?? this.lastDocuments,
    askDefaultApp: askDefaultApp ?? this.askDefaultApp,
    pageLook: pageLook ?? this.pageLook,
    pageLayout: pageLayout ?? this.pageLayout,
    zoom: zoom ?? this.zoom,
    missingGlyphs: missingGlyphs ?? this.missingGlyphs,
    recoveryCopies: recoveryCopies ?? this.recoveryCopies,
    reflow: reflow ?? this.reflow,
    markEdited: markEdited ?? this.markEdited,
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
      other.reopenDocuments == reopenDocuments &&
      listEquals(other.lastDocuments, lastDocuments) &&
      other.askDefaultApp == askDefaultApp &&
      other.pageLook == pageLook &&
      other.pageLayout == pageLayout &&
      other.zoom == zoom &&
      other.missingGlyphs == missingGlyphs &&
      other.recoveryCopies == recoveryCopies &&
      other.reflow == reflow &&
      other.markEdited == markEdited &&
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
    reopenDocuments,
    Object.hashAll(lastDocuments),
    askDefaultApp,
    pageLook,
    pageLayout,
    zoom,
    missingGlyphs,
    recoveryCopies,
    reflow,
    markEdited,
    version,
    Object.hashAllUnordered(unknown.keys),
  );

  @override
  String toString() => 'AppSettings(${toJson()})';
}

/// How PDF pages look in the dark theme (a11-1, B078).
enum PageLook {
  /// Pages as printed.
  paper,

  /// Pages through the dim page filter.
  dimmed,
}

/// The page layout a document opens with (a11-1, B035).
enum NewDocumentLayout {
  /// Continuous scroll.
  scroll,

  /// Single page.
  single,

  /// Two-page spread.
  spread,
}

/// The zoom a document opens with (a11-1, B034).
enum NewDocumentZoom {
  /// Fit width.
  fitWidth,

  /// Fit page.
  fitPage,

  /// Actual size, 100 %.
  actual,
}

/// What missing-glyph step 3 does (a11-1c's "When a font is missing a
/// character", G36).
enum MissingGlyphPolicy {
  /// "Use a similar font and say so": the closest candidate draws the
  /// characters at once, said once; the default (Q09).
  similar,

  /// "Ask each time": nothing is drawn until a font is chosen.
  ask,

  /// "Keep the original font and mark the character": the characters stay
  /// in their font without a glyph, and are marked.
  mark,
}
