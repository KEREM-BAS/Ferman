import 'package:ferman/design/theme.dart';
import 'package:flutter/material.dart' show Brightness, ThemeData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FermanTheme.light and dark', () {
    test('carry the light and dark token sets', () {
      final light = FermanTheme.light;
      expect(light.brightness, Brightness.light);
      expect(light.isDark, isFalse);
      expect(light.colors, same(FermanColorTokens.light));
      expect(light.elevation, same(FermanElevationTokens.light));
      expect(light.focus, same(FermanFocusTokens.light));
      final dark = FermanTheme.dark;
      expect(dark.isDark, isTrue);
      expect(dark.colors, same(FermanColorTokens.dark));
      expect(dark.elevation, same(FermanElevationTokens.dark));
      expect(dark.focus, same(FermanFocusTokens.dark));
      // ADR 0012 spot values.
      expect(dark.colors.surfaceCanvas, const Color(0xFF0E0E0D));
      expect(dark.focus.focusRing.last.color, const Color(0xFF1D1C1B));
    });

    test('default to desktop density, standard motion and no filter', () {
      for (final theme in [FermanTheme.light, FermanTheme.dark]) {
        expect(theme.density, same(FermanDensityTokens.desktop));
        expect(theme.motion, same(FermanMotionTokens.standard));
        expect(theme.pageFilter, same(FermanPageFilterTokens.standard));
        expect(theme.pageColorFilter, isNull);
        expect(theme.typography, same(FermanTypography.standard));
      }
    });

    test('forBrightness picks light or dark', () {
      expect(
        FermanTheme.forBrightness(Brightness.light),
        same(FermanTheme.light),
      );
      expect(
        FermanTheme.forBrightness(Brightness.dark),
        same(FermanTheme.dark),
      );
    });
  });

  group('resolve', () {
    test('reduced motion takes the reduced durations', () {
      final reduced = FermanTheme.light.resolve(reduceMotion: true);
      expect(reduced.motion, same(FermanMotionTokens.reduced));
      expect(reduced.motion.durBase, Duration.zero);
      expect(reduced.motion.durFast, Duration.zero);
      expect(reduced.motion.durInstant, Duration.zero);
      expect(reduced.motion.durSlow, Duration.zero);
      final standard = FermanTheme.light.resolve();
      expect(standard.motion.durBase, const Duration(milliseconds: 180));
    });

    test('motionFor gives the set resolve picks', () {
      expect(
        FermanTheme.motionFor(reduceMotion: true),
        same(FermanMotionTokens.reduced),
      );
      expect(
        FermanTheme.motionFor(reduceMotion: false),
        same(FermanMotionTokens.standard),
      );
      for (final reduce in [true, false]) {
        expect(
          FermanTheme.dark.resolve(reduceMotion: reduce).motion,
          same(FermanTheme.motionFor(reduceMotion: reduce)),
        );
      }
    });

    test('touch takes the touch density', () {
      final touch = FermanTheme.dark.resolve(touch: true);
      expect(touch.density, same(FermanDensityTokens.touch));
      expect(touch.density.hitMin, 44);
      expect(FermanTheme.dark.resolve().density.hitMin, 24);
    });

    test('pageDim takes the dim filter as a colour matrix', () {
      final dim = FermanTheme.dark.resolve(pageDim: true);
      expect(dim.pageFilter, same(FermanPageFilterTokens.dim));
      expect(
        dim.pageColorFilter,
        ColorFilter.matrix(FermanPageFilterTokens.dim.pageFilter!),
      );
    });

    test('the locale picks the type roles', () {
      final ja = FermanTheme.light.resolve(locale: const Locale('ja'));
      expect(ja.typography.isCjk, isTrue);
      expect(ja.typography.locale, const Locale('ja'));
    });

    test('keeps the colours and is idempotent', () {
      final once = FermanTheme.dark.resolve(
        locale: const Locale('tr'),
        reduceMotion: true,
        touch: true,
        pageDim: true,
      );
      expect(once.colors, same(FermanColorTokens.dark));
      expect(once.brightness, Brightness.dark);
      final twice = once.resolve(
        locale: const Locale('tr'),
        reduceMotion: true,
        touch: true,
        pageDim: true,
      );
      expect(twice, once);
      expect(twice.hashCode, once.hashCode);
      expect(FermanTheme.dark.resolve(), FermanTheme.dark);
    });
  });

  group('copyWith', () {
    test('replaces only the given sets', () {
      final copy = FermanTheme.light.copyWith(colors: FermanColorTokens.dark);
      expect(copy.colors, same(FermanColorTokens.dark));
      expect(copy.brightness, Brightness.light);
      expect(copy.elevation, same(FermanElevationTokens.light));
      expect(FermanTheme.light.copyWith(), FermanTheme.light);
    });
  });

  group('lerp', () {
    test('returns this for null, itself and equal sets', () {
      final light = FermanTheme.light;
      expect(light.lerp(null, 0.5), same(light));
      expect(light.lerp(light, 0.5), same(light));
      final lerped = light.lerp(light.copyWith(), 0.5);
      expect(lerped.colors, same(FermanColorTokens.light));
      expect(lerped.density, same(FermanDensityTokens.desktop));
      expect(lerped, light);
    });

    test('interpolates colours and switches the brightness at 0.5', () {
      final light = FermanTheme.light;
      final dark = FermanTheme.dark;
      final start = light.lerp(dark, 0);
      expect(start.colors.textPrimary, FermanColorTokens.light.textPrimary);
      final end = light.lerp(dark, 1);
      expect(end.colors.textPrimary, FermanColorTokens.dark.textPrimary);
      expect(end.brightness, Brightness.dark);
      final middle = light.lerp(dark, 0.5);
      expect(
        middle.colors.surfaceCanvas,
        Color.lerp(
          FermanColorTokens.light.surfaceCanvas,
          FermanColorTokens.dark.surfaceCanvas,
          0.5,
        ),
      );
      expect(light.lerp(dark, 0.49).brightness, Brightness.light);
      expect(middle.brightness, Brightness.dark);
    });

    test('switches motion, density and the page filter at 0.5', () {
      final from = FermanTheme.light;
      final to = FermanTheme.light.resolve(
        reduceMotion: true,
        touch: true,
        pageDim: true,
      );
      final before = from.lerp(to, 0.25);
      expect(before.motion.durBase, const Duration(milliseconds: 180));
      expect(before.pageFilter.pageFilter, isNull);
      expect(before.density.hitMin, closeTo(24 + 20 * 0.25, 1e-9));
      final after = from.lerp(to, 0.75);
      expect(after.motion.durBase, Duration.zero);
      expect(after.pageFilter.pageFilter, isNotNull);
    });
  });

  group('the views of the constant sets', () {
    test('give the generated constants', () {
      final theme = FermanTheme.light;
      expect(theme.space.space2, FermanSpaceTokens.space2);
      expect(theme.space.space1_5, 6);
      expect(theme.radius.radiusMd, FermanRadiusTokens.radiusMd);
      expect(theme.size.panelW, 264);
      expect(theme.border.borderWidth, 1);
      expect(theme.z.zTooltip, FermanZTokens.zTooltip);
      expect(theme.ramps.ink600, FermanRampTokens.ink600);
      expect(theme.pageColors.editChanged, const Color(0xFF2A4DAF));
      expect(theme.typeScale.sizeMd, 13);
      expect(theme.hatch.redactPending, same(FermanHatchTokens.redactPending));
    });

    test('are the same in light and dark', () {
      expect(
        FermanTheme.dark.pageColors.pageBg,
        FermanTheme.light.pageColors.pageBg,
      );
    });
  });

  group('FermanMaterialTheme', () {
    test('builds equal themes on each read', () {
      expect(FermanMaterialTheme.light, FermanMaterialTheme.light);
      expect(FermanMaterialTheme.dark, isNot(FermanMaterialTheme.light));
    });

    test('carries the extension and the minimum Material settings', () {
      for (final (data, ferman) in [
        (FermanMaterialTheme.light, FermanTheme.light),
        (FermanMaterialTheme.dark, FermanTheme.dark),
      ]) {
        expect(data.brightness, ferman.brightness);
        expect(data.extension<FermanTheme>(), same(ferman));
        expect(data.colorScheme.primary, ferman.colors.accent);
        expect(data.colorScheme.surface, ferman.colors.surfacePanel);
        expect(data.canvasColor, ferman.colors.surfacePanel);
        expect(data.iconTheme.color, ferman.colors.textPrimary);
        expect(data.iconTheme.size, ferman.density.iconMd);
        expect(
          data.textSelectionTheme.selectionColor,
          FermanPageColorTokens.editSelection,
        );
      }
    });

    test('animates between light and dark through the extension', () {
      final middle = ThemeData.lerp(
        FermanMaterialTheme.light,
        FermanMaterialTheme.dark,
        0.5,
      );
      final ferman = middle.extension<FermanTheme>()!;
      expect(
        ferman.colors.textPrimary,
        Color.lerp(
          FermanColorTokens.light.textPrimary,
          FermanColorTokens.dark.textPrimary,
          0.5,
        ),
      );
    });
  });
}
