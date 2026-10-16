import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

void main() {
  group('classifyToken', () {
    test('colours', () {
      expect(
        classifyToken('ink-600', '#2A4DAF'),
        isA<ColorValue>().having((v) => v.argb, 'argb', 0xFF2A4DAF),
      );
      expect(
        classifyToken('surface-hover', 'rgba(31, 29, 26, 0.06)'),
        isA<ColorValue>().having((v) => v.argb, 'argb', 0x0F1F1D1A),
      );
    });

    test('lengths, including a unitless zero', () {
      expect(
        classifyToken('space-1-5', '6px'),
        isA<LengthValue>().having((v) => v.px, 'px', 6),
      );
      expect(classifyToken('space-0', '0'), isA<LengthValue>());
      expect(
        classifyToken('border-width-strong', '1.5px'),
        isA<LengthValue>().having((v) => v.px, 'px', 1.5),
      );
    });

    test('tracking is em, even when the value is a bare 0', () {
      expect(
        classifyToken('tracking-tight', '-0.01em'),
        isA<EmValue>().having((v) => v.em, 'em', -0.01),
      );
      expect(
        classifyToken('tracking-normal', '0'),
        isA<EmValue>().having((v) => v.em, 'em', 0),
      );
    });

    test('font weights by name', () {
      expect(
        classifyToken('weight-medium', '500'),
        isA<FontWeightValue>().having((v) => v.weight, 'weight', 500),
      );
    });

    test('@kind other: durations, easings, z-index and filters', () {
      expect(
        classifyToken('dur-fast', '120ms', kindHint: 'other'),
        isA<DurationValue>().having((v) => v.microseconds, 'µs', 120000),
      );
      expect(
        classifyToken(
          'ease-out',
          'cubic-bezier(0.2, 0, 0, 1)',
          kindHint: 'other',
        ),
        isA<CubicValue>()
            .having((v) => v.a, 'a', 0.2)
            .having((v) => v.d, 'd', 1),
      );
      expect(
        classifyToken('z-toast', '300', kindHint: 'other'),
        isA<IntegerValue>().having((v) => v.value, 'value', 300),
      );
      expect(
        classifyToken('page-filter', 'none', kindHint: 'other'),
        isA<FilterValue>().having((v) => v.functions, 'functions', isEmpty),
      );
      expect(
        classifyToken(
          'page-filter',
          'brightness(0.86) contrast(1.04) sepia(6%)',
          kindHint: 'other',
        ),
        isA<FilterValue>().having(
          (v) => v.functions.map((f) => '${f.name}:${f.amount}'),
          'functions',
          ['brightness:0.86', 'contrast:1.04', 'sepia:0.06'],
        ),
      );
    });

    test('@kind font: features and stacks', () {
      expect(
        classifyToken('numeric-tabular', 'tabular-nums', kindHint: 'font'),
        isA<FontFeaturesValue>().having(
          (v) => v.features.single.tag,
          'tag',
          'tnum',
        ),
      );
      expect(
        classifyToken('features-ui', "'kern' 1, 'liga' 1", kindHint: 'font'),
        isA<FontFeaturesValue>().having(
          (v) => v.features.map((f) => f.tag),
          'tags',
          ['kern', 'liga'],
        ),
      );
    });

    test('font stacks need a quoted family', () {
      expect(
        classifyToken('font-hand-1', "'Caveat', cursive"),
        isA<FontStackValue>().having((v) => v.families, 'families', [
          'Caveat',
          'cursive',
        ]),
      );
    });

    test('the font shorthand', () {
      final value = classifyToken(
        'type-body',
        "400 13px/18px 'IBM Plex Sans', system-ui, sans-serif",
      );
      expect(
        value,
        isA<FontShorthandValue>()
            .having((v) => v.weight, 'weight', 400)
            .having((v) => v.size, 'size', 13)
            .having((v) => v.lineHeightPx, 'lineHeightPx', 18)
            .having((v) => v.families.first, 'family', 'IBM Plex Sans'),
      );
      expect(
        classifyToken('type-wordmark', "600 16px/1 'IBM Plex Serif', serif"),
        isA<FontShorthandValue>().having(
          (v) => v.lineHeightNumber,
          'lineHeightNumber',
          1,
        ),
      );
    });

    test('a font shorthand without a line height, or with normal', () {
      for (final css in [
        "400 13px 'IBM Plex Sans'",
        "400 13px/normal 'IBM Plex Sans'",
      ]) {
        expect(
          classifyToken('type-x', css),
          isA<FontShorthandValue>()
              .having((v) => v.size, 'size', 13)
              .having((v) => v.lineHeightPx, 'lineHeightPx', isNull)
              .having((v) => v.lineHeightNumber, 'lineHeightNumber', isNull),
          reason: css,
        );
      }
    });

    test('shadows: multiple layers, rings, negative spread and inset', () {
      final value = classifyToken(
        'shadow-popover',
        '0 0 0 1px rgba(20, 19, 17, 0.08), 0 12px 28px -6px #000000',
      );
      expect(value, isA<ShadowValue>());
      final layers = (value as ShadowValue).layers;
      expect(layers, hasLength(2));
      expect(layers.first.spread, 1);
      expect(layers.last.spread, -6);
      expect(layers.last.blur, 28);
      final inset = classifyToken(
        'focus-ring-inset',
        'inset 0 0 0 2px #3A60C6',
      );
      expect((inset as ShadowValue).layers.single.inset, isTrue);
    });

    test('outlines', () {
      expect(
        classifyToken('focus-outline', '2px solid #3A60C6'),
        isA<BorderValue>()
            .having((v) => v.width, 'width', 2)
            .having((v) => v.argb, 'argb', 0xFF3A60C6),
      );
    });

    test('fails on values it cannot type', () {
      expect(
        () => classifyToken('mystery', 'banana split'),
        throwsA(isA<TokenException>()),
      );
    });

    test('fails when a value contradicts its @kind hint', () {
      expect(
        () => classifyToken('dur-fast', '12px', kindHint: 'other'),
        throwsA(isA<TokenException>()),
      );
      expect(
        () => classifyToken('x', '1px', kindHint: 'colour'),
        throwsA(isA<TokenException>()),
      );
    });
  });
}
