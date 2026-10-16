import 'package:ferman/design/theme.dart';
import 'package:ferman/design/theme/theme_override.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The themes the gallery previews: the design's `data-theme` light and
/// dark, and dark with the dim page filter (`data-page="dim"`), the
/// combination the design offers for reading in the dark theme.
enum GalleryTheme {
  /// The light theme.
  light,

  /// The dark theme; PDF pages stay paper-white.
  dark,

  /// The dark theme with dimmed PDF pages.
  dim;

  /// The brightness of the chrome.
  Brightness get brightness =>
      this == light ? Brightness.light : Brightness.dark;

  /// Whether PDF pages take the dim filter.
  bool get pageDim => this == dim;
}

/// The UI languages the gallery previews: English (the source), Turkish
/// (complete) and Arabic (right to left).
const List<AppLanguage> galleryLanguages = [
  AppLanguage.english,
  AppLanguage.turkish,
  AppLanguage.arabic,
];

/// What the gallery previews its components in. Local to the gallery: it
/// never changes the app's settings.
@immutable
final class GalleryPreview {
  /// The preview with these settings; by default light, desktop density,
  /// standard motion, English, left to right.
  const new({
    this.theme = GalleryTheme.light,
    this.touch = false,
    this.reducedMotion = false,
    this.language = AppLanguage.english,
    this.direction = TextDirection.ltr,
  });

  /// Light, dark or dim.
  final GalleryTheme theme;

  /// Whether the touch density (`data-density="touch"`) replaces the
  /// desktop one.
  final bool touch;

  /// Whether every duration token is zero, as under the system's reduced
  /// motion setting.
  final bool reducedMotion;

  /// The UI language of the components' copy.
  final AppLanguage language;

  /// The layout direction; follows [language] when it changes, and can be
  /// switched on its own.
  final TextDirection direction;

  /// The region whose formats the components use: the preview language's
  /// own region (Türkiye for Turkish), so a language switch shows the
  /// region formats too. The app itself keeps the region setting apart
  /// from the language (G34).
  Region get region => Region.fromLocale(language.uiLocale);

  /// This preview with the given settings changed. A new [language] also
  /// sets the direction to the language's own, unless [direction] is
  /// given.
  GalleryPreview copyWith({
    GalleryTheme? theme,
    bool? touch,
    bool? reducedMotion,
    AppLanguage? language,
    TextDirection? direction,
  }) => GalleryPreview(
    theme: theme ?? this.theme,
    touch: touch ?? this.touch,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    language: language ?? this.language,
    direction: direction ?? language?.textDirection ?? this.direction,
  );

  @override
  bool operator ==(Object other) =>
      other is GalleryPreview &&
      other.theme == theme &&
      other.touch == touch &&
      other.reducedMotion == reducedMotion &&
      other.language == language &&
      other.direction == direction;

  @override
  int get hashCode =>
      Object.hash(theme, touch, reducedMotion, language, direction);
}

/// What the gallery's samples need beyond the theme: the region formats
/// and the key conventions of the shortcut table.
class GalleryEnvironment extends InheritedWidget {
  /// Provides [region] and [shortcuts] to [child].
  const new({
    required this.region,
    required this.shortcuts,
    required super.child,
    super.key,
  });

  /// The region the samples format numbers, dates and times for.
  final Region region;

  /// The key conventions the samples' shortcuts are written in.
  final ShortcutPlatform shortcuts;

  /// The environment at [context]: the nearest one, or the United States
  /// region with the running system's keys when there is none.
  static GalleryEnvironment of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryEnvironment>() ??
      _fallback;

  static final GalleryEnvironment _fallback = GalleryEnvironment(
    region: Region.unitedStates,
    shortcuts: ShortcutPlatform.current,
    child: const SizedBox.shrink(),
  );

  /// The key caps of [command], as tooltips and menus show them.
  List<String>? caps(ShellCommand command) => command.caps(shortcuts);

  @override
  bool updateShouldNotify(GalleryEnvironment oldWidget) =>
      region != oldWidget.region || shortcuts != oldWidget.shortcuts;
}

/// Applies [preview] to [child]: reduced motion, the UI language, the text
/// direction, the light or dark theme with the density and page filter,
/// the panel background, an [Overlay] of its own for tooltips and
/// popovers, and the [GalleryEnvironment].
///
/// The order matters: [Localizations.override] sets a [Directionality] of
/// its own, so the chosen direction comes below it, and the theme scope
/// reads the locale and reduced motion, so it comes below both.
class GalleryPreviewScope extends StatelessWidget {
  /// Previews [child] as [preview] says, with the key caps of [shortcuts].
  const new({
    required this.preview,
    required this.shortcuts,
    required this.child,
    super.key,
  });

  /// The settings to apply.
  final GalleryPreview preview;

  /// The key conventions of the samples' shortcuts.
  final ShortcutPlatform shortcuts;

  /// The previewed content.
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(disableAnimations: preview.reducedMotion),
    child: Localizations.override(
      context: context,
      locale: preview.language.uiLocale,
      child: Directionality(
        textDirection: preview.direction,
        child: FermanThemeOverride(
          brightness: preview.theme.brightness,
          child: FermanThemeScope(
            touch: preview.touch,
            pageDim: preview.theme.pageDim,
            child: GalleryEnvironment(
              region: preview.region,
              shortcuts: shortcuts,
              child: _PreviewSurface(child: Overlay.wrap(child: child)),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<GalleryPreview>('preview', preview))
      ..add(EnumProperty<ShortcutPlatform>('shortcuts', shortcuts));
  }
}

/// The previewed theme's panel background (`.fm-root`).
class _PreviewSurface extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.ferman.colors.surfacePanel, child: child);
}
