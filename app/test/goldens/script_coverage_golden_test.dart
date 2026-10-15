import 'package:alchemist/alchemist.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The ROADMAP §5 step 5 sample: Turkish, Vietnamese, Cyrillic, Greek,
/// Arabic, Persian, Hebrew and Devanagari in one line.
const String scriptSample =
    'İMZALA ğ ş ı · Tiếng Việt · Русский · Ελληνικά · العربية · فارسی · '
    'עברית · हिन्दी';

/// A font chain of ARCHITECTURE §11.5 and the direction it is shown in.
final class _Chain {
  const new(this.label, this.families, this.direction);

  final String label;
  final List<String> families;
  final TextDirection direction;

  TextStyle style({required double size, FontWeight? weight}) => TextStyle(
    fontFamily: families.first,
    fontFamilyFallback: families.skip(1).toList(),
    fontSize: size,
    fontWeight: weight ?? FermanTypeTokens.weightRegular,
    color: FermanColorTokens.light.textPrimary,
  );
}

// Every UI language but CJK uses the design's `--font-ui` order: IBM Plex
// Sans first, then Plex Sans Arabic, Hebrew and Devanagari, as the 12
// Localization boards do for ar. No script font comes first. Plex Sans
// Arabic, Hebrew and Devanagari lack İ, ş and ế but carry I, s, ê and the
// combining marks U+0307, U+0327 and U+0301, so with one of them first
// those letters are drawn from it as base plus mark instead of falling back
// to Plex Sans. Plex Sans Devanagari misplaces all three marks (İ loses its
// dot, the cedilla of ş floats); Plex Sans Arabic and Hebrew place İ and ş
// correctly but set the acute of ế beside the circumflex. With Plex Sans
// first, Arabic, Persian, Hebrew and Devanagari text renders pixel for
// pixel as it does with its script font first.
final List<String> _fontUi = [
  ?FermanTypeTokens.fontUi.family,
  ...FermanTypeTokens.fontUi.fallback,
];

final _Chain _ltrChain = _Chain(
  '--font-ui, left to right (Latin and Cyrillic UIs, hi)',
  _fontUi,
  TextDirection.ltr,
);

final _Chain _rtlChain = _Chain(
  '--font-ui, right to left (ar, fa, he)',
  _fontUi,
  TextDirection.rtl,
);

Widget _sample(_Chain chain, {required double size, FontWeight? weight}) =>
    Text(
      scriptSample,
      textDirection: chain.direction,
      style: chain.style(size: size, weight: weight),
    );

String _weightName(FontWeight weight) => '${weight.value}';

Future<void> main() async {
  await goldenTest(
    'the bundled fonts cover every script of the sample without fallback '
    'glyphs',
    fileName: 'script_coverage',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final size in [
          FermanTypeTokens.sizeXs,
          FermanTypeTokens.sizeMd,
          FermanTypeTokens.sizeXl,
          FermanTypeTokens.size2xl,
        ])
          GoldenTestScenario(
            name: '${_ltrChain.label}, 400, ${size.round()} px',
            child: _sample(_ltrChain, size: size),
          ),
        for (final weight in [
          FermanTypeTokens.weightMedium,
          FermanTypeTokens.weightSemibold,
        ])
          GoldenTestScenario(
            name:
                '${_ltrChain.label}, ${_weightName(weight)}, '
                '${FermanTypeTokens.sizeMd.round()} px',
            child: _sample(
              _ltrChain,
              size: FermanTypeTokens.sizeMd,
              weight: weight,
            ),
          ),
        GoldenTestScenario(
          name:
              '${_rtlChain.label}, 400, ${FermanTypeTokens.sizeLg.round()} px',
          child: _sample(_rtlChain, size: FermanTypeTokens.sizeLg),
        ),
      ],
    ),
  );
}
