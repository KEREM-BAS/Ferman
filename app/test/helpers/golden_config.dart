import 'package:alchemist/alchemist.dart';
import 'package:ferman/design/tokens.g.dart';
// alchemist's configuration takes a Material ThemeData; nothing else from
// Material is used.
import 'package:flutter/material.dart' show ThemeData;
import 'package:flutter/widgets.dart' hide Icon;

/// The IBM Plex Sans stack the design's `--font-ui` keeps after dropping
/// the families that are not bundled.
final TextStyle goldenLabelStyle = TextStyle(
  fontFamily: FermanTypeTokens.fontUi.family,
  fontFamilyFallback: FermanTypeTokens.fontUi.fallback,
  fontSize: FermanTypeTokens.sizeSm,
  height: FermanTypeTokens.heightSm,
  color: FermanColorTokens.light.textSecondary,
);

/// The alchemist configuration of every golden test
/// (`flutter_test_config.dart`).
///
/// - Platform goldens on Linux only, with real text and shadows: goldens
///   are generated and compared on the Linux runner, where font
///   rasterisation is stable (ADR 0017, ARCHITECTURE §13.5). Other systems
///   skip them, and CI runs `flutter test --exclude-tags golden` there.
/// - No CI goldens: alchemist's CI variant draws text as boxes, and Ferman
///   goldens must show the real bundled fonts.
/// - A minimal theme: the alchemist wrapper is Material, so its default
///   text falls back to the IBM Plex Sans stack instead of the test font.
///   Screens bring their own Ferman theme.
/// - Golden files live in `goldens/linux/` next to each test, alchemist's
///   default. Scenarios get an 8 px inset so labels do not touch the
///   dividers.
final AlchemistConfig fermanAlchemistConfig = AlchemistConfig(
  theme: ThemeData(
    fontFamily: FermanTypeTokens.fontUi.family,
    fontFamilyFallback: FermanTypeTokens.fontUi.fallback,
  ),
  goldenTestTheme: GoldenTestTheme(
    backgroundColor: FermanColorTokens.light.surfacePanel,
    borderColor: FermanColorTokens.light.borderDefault,
    nameTextStyle: goldenLabelStyle,
    padding: const EdgeInsetsDirectional.all(8),
  ),
  platformGoldensConfig: PlatformGoldensConfig(platforms: {HostPlatform.linux}),
  ciGoldensConfig: const CiGoldensConfig(enabled: false),
);

/// Whether this host generates and compares goldens: Linux only
/// ([fermanAlchemistConfig]).
///
/// On any other host alchemist's test variant has no values, and
/// flutter_test fails such a test while the file loads, before
/// `--exclude-tags golden` applies. Golden tests therefore pass
/// `skip: !isGoldenHost`, which declares nothing on macOS and Windows.
final bool isGoldenHost = fermanAlchemistConfig.platformGoldensConfig.platforms
    .contains(HostPlatform.current());
