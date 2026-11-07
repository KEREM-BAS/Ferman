import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fonts_pane.g.dart';

/// The font families bundled with Ferman and installed on this computer,
/// read by the engine off the UI isolate each time the pane opens, as
/// `installedFontsProvider`. None when the engine cannot read them.
@riverpod
Future<List<InstalledFont>> installedFonts(Ref ref) async {
  try {
    return await ref.watch(engineServiceProvider).installedFonts();
  } on Exception {
    return const [];
  }
}

/// a11-1d's filter.
enum _Filter { turkish, all, openDocuments }

/// The Fonts pane of Settings, board a11-1d: the fonts bundled and
/// installed, each with a Turkish test string in its own face and its
/// script coverage, read from the font files by the engine. The search
/// matches the family name; the filter keeps the fonts that cover Turkish
/// (the default) or all of them. "Used in open documents" stays disabled
/// (B214).
///
/// A code the font cannot draw is struck through as well as dimmed, as the
/// legend says (the board only dims it).
class FontsPane extends ConsumerStatefulWidget {
  /// The pane.
  const new({super.key});

  /// The filter's width (`190px`).
  static const double filterWidth = 190;

  /// The gap between the search and the filter (`gap: 10px`).
  static const double barGap = 10;

  /// The name column's width (`grid-template-columns: 200px …`).
  static const double nameWidth = 200;

  /// The gap between a row's columns (`gap: 14px`).
  static const double columnGap = 14;

  /// A row's padding (`padding: 10px 14px`): vertical …
  static const double rowPaddingY = 10;

  /// … and horizontal.
  static const double rowPaddingX = 14;

  /// The test string's size (`font-size: 17px`).
  static const double sampleSize = 17;

  /// The chips' gap (`gap: 4px`).
  static const double chipGap = 4;

  /// A chip's padding (`padding: 1px 5px`): vertical …
  static const double chipPaddingY = 1;

  /// … and horizontal.
  static const double chipPaddingX = 5;

  /// A chip's type (`font: 500 10px/1.5`).
  static const double chipSize = 10;

  /// A chip's line height.
  static const double chipHeight = 1.5;

  /// The test string, Turkish in every language (`lang="tr"`).
  static const String sample = 'Ağ Iı İi Şş Çç Öö Üü';

  /// The chips' codes, in the scripts' order.
  static const Map<FontScript, String> codes = {
    FontScript.turkish: 'TR',
    FontScript.latinExtended: 'LX',
    FontScript.cyrillic: 'CY',
    FontScript.greek: 'GR',
    FontScript.arabic: 'AR',
    FontScript.hebrew: 'HE',
    FontScript.devanagari: 'DV',
    FontScript.cjk: 'CJK',
  };

  @override
  ConsumerState<FontsPane> createState() => _FontsPaneState();
}

class _FontsPaneState extends ConsumerState<FontsPane> {
  String _query = '';
  _Filter _filter = _Filter.turkish;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final fonts = ref.watch(installedFontsProvider);
    final all = fonts.value ?? const <InstalledFont>[];
    final query = casing.lower(_query.trim());
    final shown = [
      for (final font in all)
        if ((_filter == _Filter.all ||
                font.scripts.contains(FontScript.turkish)) &&
            casing.lower(font.family).contains(query))
          font,
    ];
    final border = BorderSide(
      color: colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusMd));

    Widget row(InstalledFont font) => Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: FontsPane.rowPaddingX,
        vertical: FontsPane.rowPaddingY,
      ),
      decoration: BoxDecoration(border: Border(bottom: border)),
      child: Row(
        spacing: FontsPane.columnGap,
        children: [
          SizedBox(
            width: FontsPane.nameWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  font.family,
                  style: typography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  font.origin == FontOrigin.bundled
                      ? l10n.settingsFontsBundled
                      : l10n.settingsFontsInstalled,
                  style: typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                FontsPane.sample,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                locale: const Locale('tr'),
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: FontsPane.sampleSize,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          Row(
            spacing: FontsPane.chipGap,
            children: [
              for (final MapEntry(key: script, value: code)
                  in FontsPane.codes.entries)
                _Chip(code: code, covers: font.scripts.contains(script)),
            ],
          ),
        ],
      ),
    );

    final Widget list;
    if (fonts.isLoading) {
      list = Padding(
        padding: EdgeInsets.all(theme.space.space6),
        child: Center(child: Spinner(semanticLabel: l10n.settingsFontsLoading)),
      );
    } else if (shown.isEmpty) {
      list = Padding(
        padding: EdgeInsets.all(theme.space.space6),
        child: EmptyState(
          icon: IconName.type,
          title: l10n.settingsFontsNoMatch,
          body: l10n.settingsSearchNoMatchBody,
        ),
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final font in shown) row(font)],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space3,
      children: [
        Row(
          spacing: FontsPane.barGap,
          children: [
            Expanded(
              child: TextField(
                size: FieldSize.sm,
                icon: IconName.search,
                placeholder: l10n.settingsFontsSearch(
                  format.integer(all.length),
                ),
                semanticLabel: l10n.settingsFontsSearchLabel,
                onChanged: (query) => setState(() => _query = query),
              ),
            ),
            SizedBox(
              width: FontsPane.filterWidth,
              child: Select<_Filter>(
                size: FieldSize.sm,
                semanticLabel: l10n.settingsFontsFilter,
                value: _filter,
                options: [
                  SelectOption(
                    value: _Filter.turkish,
                    label: l10n.settingsFontsFilterTurkish,
                  ),
                  SelectOption(
                    value: _Filter.all,
                    label: l10n.settingsFontsFilterAll,
                  ),
                  SelectOption(
                    value: _Filter.openDocuments,
                    label: l10n.settingsFontsFilterOpen,
                    disabled: true,
                    disabledReason: Feature.fontsInOpenDocuments.disabledReason(
                      context,
                    ),
                  ),
                ],
                onChanged: (filter) => setState(() => _filter = filter),
              ),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(border),
              borderRadius: radius,
            ),
            child: list,
          ),
        ),
        Text(
          l10n.settingsFontsLegend,
          style: typography.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// A coverage chip: the script's code on `--success-bg` in `--success`
/// when the font covers it, else struck through in `--text-disabled`.
class _Chip extends StatelessWidget {
  const new({required this.code, required this.covers});

  final String code;
  final bool covers;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: covers
          ? l10n.settingsFontsCovers(code)
          : l10n.settingsFontsMissing(code),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: FontsPane.chipPaddingX,
          vertical: FontsPane.chipPaddingY,
        ),
        decoration: BoxDecoration(
          color: covers ? colors.successBg : null,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusXs),
          ),
        ),
        child: Text(
          code,
          style: theme.typography.label.copyWith(
            fontSize: FontsPane.chipSize,
            height: FontsPane.chipHeight,
            fontWeight: theme.typeScale.weightMedium,
            color: covers ? colors.success : colors.textDisabled,
            decoration: covers ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}
