import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

import 'support.dart';

String mapped(TokenValue value) =>
    compact(mapValue(value, name: 'test').expression);

void main() {
  group('flutterBlurRadius', () {
    test('matches the CSS Gaussian sigma', () {
      for (final blur in [2.0, 6.0, 12.0, 20.0, 56.0]) {
        final radius = flutterBlurRadius(blur);
        // Flutter: sigma = 0.57735 × radius + 0.5. CSS: sigma = blur / 2.
        expect(radius * 0.57735 + 0.5, closeTo(blur / 2, 1e-9));
      }
      expect(flutterBlurRadius(2), closeTo(0.866, 0.001));
    });

    test('keeps a hard edge for blur 0 and clamps small blurs at 0', () {
      expect(flutterBlurRadius(0), 0);
      expect(flutterBlurRadius(1), 0);
    });
  });

  group('shadows', () {
    test('reverse the layer order and turn rings into spread', () {
      const value = ShadowValue([
        ShadowLayer(
          inset: false,
          x: 0,
          y: 0,
          blur: 0,
          spread: 1,
          argb: 0x14141311,
        ),
        ShadowLayer(
          inset: false,
          x: 0,
          y: 12,
          blur: 28,
          spread: -6,
          argb: 0x24141311,
        ),
      ]);
      expect(mapValue(value, name: 'test').type, 'List<BoxShadow>');
      expect(
        mapped(value),
        '<BoxShadow>['
        'BoxShadow(color:Color(0x24141311),offset:Offset(0,12),'
        'blurRadius:23.3827,spreadRadius:-6),'
        'BoxShadow(color:Color(0x14141311),spreadRadius:1)'
        ']',
      );
    });

    test('an inset ring becomes an inside border', () {
      const value = ShadowValue([
        ShadowLayer(
          inset: true,
          x: 0,
          y: 0,
          blur: 0,
          spread: 2,
          argb: 0xFF3A60C6,
        ),
      ]);
      expect(mapValue(value, name: 'test').type, 'BorderSide');
      expect(mapped(value), 'BorderSide(color:Color(0xFF3A60C6),width:2)');
    });

    test('other inset shadows cannot be mapped', () {
      const value = ShadowValue([
        ShadowLayer(inset: true, x: 0, y: 1, blur: 2, spread: 0, argb: 0),
      ]);
      expect(
        () => mapValue(value, name: 'test'),
        throwsA(isA<TokenException>()),
      );
    });
  });

  group('other values', () {
    test('outline', () {
      expect(
        mapped(const BorderValue(width: 2, style: 'solid', argb: 0xFF3A60C6)),
        'BorderSide(color:Color(0xFF3A60C6),width:2,'
        'strokeAlign:BorderSide.strokeAlignOutside)',
      );
    });

    test('durations', () {
      expect(mapped(const DurationValue(0)), 'Duration.zero');
      expect(mapped(const DurationValue(180000)), 'Duration(milliseconds:180)');
      expect(mapped(const DurationValue(1500)), 'Duration(microseconds:1500)');
    });

    test('cubic', () {
      expect(mapped(const CubicValue(0.2, 0, 0, 1)), 'Cubic(0.2,0,0,1)');
    });

    test('weights and features', () {
      expect(mapped(const FontWeightValue(600)), 'FontWeight.w600');
      expect(
        mapped(const FontFeaturesValue([FontFeatureSetting('tnum', 1)])),
        '<FontFeature>[FontFeature.tabularFigures()]',
      );
    });

    test('font shorthand keeps bundled families and a height ratio', () {
      expect(
        mapped(
          const FontShorthandValue(
            italic: false,
            weight: 500,
            size: 11,
            lineHeightPx: 14,
            lineHeightNumber: null,
            families: ['IBM Plex Sans', 'IBM Plex Sans JP', 'sans-serif'],
          ),
        ),
        "TextStyle(fontFamily:'IBMPlexSans',fontSize:11,"
        'fontWeight:FontWeight.w500,height:14/11,'
        'leadingDistribution:TextLeadingDistribution.even)',
      );
    });

    test('font shorthand with a unitless line height', () {
      expect(
        mapped(
          const FontShorthandValue(
            italic: false,
            weight: 600,
            size: 16,
            lineHeightPx: null,
            lineHeightNumber: 1.25,
            families: ['IBM Plex Serif', 'serif'],
          ),
        ),
        "TextStyle(fontFamily:'IBMPlexSerif',fontSize:16,"
        'fontWeight:FontWeight.w600,height:1.25,'
        'leadingDistribution:TextLeadingDistribution.even)',
      );
    });

    test('font shorthand without a line height leaves height null', () {
      // CSS `normal` is the font's own line height; no ratio is invented.
      expect(
        mapped(
          const FontShorthandValue(
            italic: true,
            weight: 400,
            size: 13,
            lineHeightPx: null,
            lineHeightNumber: null,
            families: ['IBM Plex Sans'],
          ),
        ),
        "TextStyle(fontFamily:'IBMPlexSans',fontSize:13,"
        'fontWeight:FontWeight.w400,fontStyle:FontStyle.italic)',
      );
    });

    test('dartNumber: ints for whole numbers, at most 4 decimals', () {
      expect(mapped(const LengthValue(13)), '13');
      expect(mapped(const LengthValue(1.5)), '1.5');
      expect(mapped(const EmValue(-0.01)), '-0.01');
      expect(mapped(const LengthValue(1 / 3)), '0.3333');
    });
  });

  group('splitFontStack', () {
    test('keeps only bundled families, in order', () {
      final split = splitFontStack([
        'IBM Plex Sans',
        'IBM Plex Sans Arabic',
        'IBM Plex Sans JP',
        'system-ui',
        'IBM Plex Sans Hebrew',
      ]);
      expect(split.family, 'IBM Plex Sans');
      expect(split.fallback, ['IBM Plex Sans Arabic', 'IBM Plex Sans Hebrew']);
      expect(split.dropped, ['IBM Plex Sans JP', 'system-ui']);
    });

    test('a stack without bundled families has no family', () {
      expect(splitFontStack(['Caveat', 'cursive']).family, isNull);
    });
  });
}
