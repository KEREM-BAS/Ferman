import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

import 'support.dart';

void main() {
  final model = designModel;

  group('spot values from the design', () {
    test('ramps', () {
      expect(valueOf(model, 'FermanRampTokens', 'ink600'), 'Color(0xFF2A4DAF)');
    });

    test('semantic colours per theme', () {
      const c = 'FermanColorTokens';
      expect(valueOf(model, c, 'surfaceCanvas', 'light'), 'Color(0xFFE8E5DF)');
      expect(valueOf(model, c, 'surfaceCanvas', 'dark'), 'Color(0xFF0E0E0D)');
      expect(valueOf(model, c, 'surfaceHover', 'light'), 'Color(0x0F1F1D1A)');
      expect(valueOf(model, c, 'surfaceHover', 'dark'), 'Color(0x12F2EFEA)');
      expect(valueOf(model, c, 'pageBorder', 'dark'), 'Color(0x80000000)');
    });

    test('the additions override the design system', () {
      const c = 'FermanPageColorTokens';
      expect(valueOf(model, c, 'editChanged'), 'Color(0xFF2A4DAF)');
      expect(valueOf(model, c, 'editChangedBg'), 'Color(0x142A4DAF)');
      // 0.70 × 255 = 178.5 rounds half up to 0xB3.
      expect(valueOf(model, c, 'searchCurrent'), 'Color(0xB3FF9F1C)');
    });

    test('a type role without a line height has no height', () {
      final model = modelFromCss({
        't.css': ":root { --type-x: 500 12px 'IBM Plex Sans', sans-serif; }",
      });
      final role = valueOf(model, 'FermanTypeRoleTokens', 'x', 'standard');
      expect(role, isNot(contains('height')));
      expect(role, isNot(contains('leadingDistribution')));
    });

    test('type roles: default and CJK', () {
      const c = 'FermanTypeRoleTokens';
      final body = valueOf(model, c, 'body', 'standard');
      expect(body, contains("fontFamily:'IBMPlexSans'"));
      expect(body, contains('fontSize:13'));
      expect(body, contains('fontWeight:FontWeight.w400'));
      expect(body, contains('height:18/13'));
      expect(
        body,
        contains('leadingDistribution:TextLeadingDistribution.even'),
      );
      expect(valueOf(model, c, 'body', 'cjk'), contains('height:20/13'));
      expect(valueOf(model, c, 'label', 'cjk'), contains('height:16/11'));
      expect(valueOf(model, c, 'prose', 'cjk'), contains('height:20/14'));
      expect(valueOf(model, c, 'wordmark', 'standard'), contains('height:1,'));
      expect(
        valueOf(model, c, 'mono', 'standard'),
        contains("fontFamily:'IBMPlexMono'"),
      );
    });

    test('shadows and the focus ring', () {
      expect(
        valueOf(model, 'FermanElevationTokens', 'shadowSm', 'light'),
        '<BoxShadow>[BoxShadow(color:Color(0x14141311),offset:Offset(0,1),'
        'blurRadius:0.866)]',
      );
      final page = valueOf(
        model,
        'FermanElevationTokens',
        'shadowPage',
        'dark',
      );
      expect(
        page,
        endsWith('BoxShadow(color:Color(0x80000000),spreadRadius:1)]'),
        reason: 'the ring paints last (on top) and uses the dark page border',
      );
      expect(
        valueOf(model, 'FermanFocusTokens', 'focusRing', 'dark'),
        '<BoxShadow>[BoxShadow(color:Color(0xFF5D7FD6),spreadRadius:4),'
        'BoxShadow(color:Color(0xFF1D1C1B),spreadRadius:2)]',
      );
      expect(
        valueOf(model, 'FermanFocusTokens', 'focusRingInset', 'light'),
        'BorderSide(color:Color(0xFF3A60C6),width:2)',
      );
    });

    test('motion', () {
      const c = 'FermanMotionTokens';
      expect(valueOf(model, c, 'easeOut', 'standard'), 'Cubic(0.2,0,0,1)');
      expect(valueOf(model, c, 'easeInOut', 'standard'), 'Cubic(0.4,0,0.2,1)');
      expect(
        valueOf(model, c, 'durBase', 'standard'),
        'Duration(milliseconds:180)',
      );
      expect(valueOf(model, c, 'durBase', 'reduced'), 'Duration.zero');
    });

    test('density, sizes, radii and z-index', () {
      const d = 'FermanDensityTokens';
      expect(valueOf(model, d, 'controlHSm', 'desktop'), '26');
      expect(valueOf(model, d, 'controlHSm', 'touch'), '44');
      expect(valueOf(model, d, 'iconSm', 'touch'), '14');
      expect(valueOf(model, 'FermanSpaceTokens', 'space1_5'), '6');
      expect(valueOf(model, 'FermanSizeTokens', 'doctabH'), '28');
      expect(valueOf(model, 'FermanRadiusTokens', 'radiusFull'), '999');
      expect(valueOf(model, 'FermanRadiusTokens', 'sheetRadius'), '12');
      expect(valueOf(model, 'FermanBorderTokens', 'borderWidthStrong'), '1.5');
      expect(valueOf(model, 'FermanZTokens', 'zTooltip'), '400');
    });

    test('type scale, tracking and font stacks', () {
      const t = 'FermanTypeTokens';
      expect(valueOf(model, t, 'sizeXs'), '11');
      expect(valueOf(model, t, 'leadingXs'), '14');
      expect(valueOf(model, t, 'heightXs'), '14/11');
      expect(valueOf(model, t, 'trackingLabel'), '0.02');
      expect(valueOf(model, t, 'weightSemibold'), 'FontWeight.w600');
      expect(
        valueOf(model, t, 'fontUi'),
        "FermanFontStack(family:'IBMPlexSans',fallback:<String>["
        "'IBMPlexSansArabic','IBMPlexSansHebrew','IBMPlexSansDevanagari'])",
      );
      expect(
        valueOf(model, t, 'fontDocCjk'),
        'FermanFontStack(family:null,fallback:<String>[])',
      );
    });

    test('the dim page filter', () {
      final dim = valueOf(model, 'FermanPageFilterTokens', 'pageFilter', 'dim');
      expect(dim, startsWith('<double>[0.8618,'));
      expect(dim.split(','), hasLength(20));
      expect(
        valueOf(model, 'FermanPageFilterTokens', 'pageFilter', 'standard'),
        'null',
      );
    });

    test('hatches from the supplement', () {
      expect(
        valueOf(model, 'FermanHatchTokens', 'redactPending'),
        'FermanHatch(angle:-45,stripes:<FermanHatchStripe>['
        'FermanHatchStripe(color:Color(0x1FB42318),width:4),'
        'FermanHatchStripe(color:Color(0x38B42318),width:2)])',
      );
    });
  });

  group('name collisions', () {
    List<String> fields(String className) =>
        model.classNamed(className).fields.map((f) => f.name).toList();

    test('--text-* colours and sizes land in different classes', () {
      expect(fields('FermanColorTokens'), contains('textPrimary'));
      expect(fields('FermanTypeTokens'), contains('sizeXs'));
      expect(
        fields('FermanTypeTokens').where((name) => name.startsWith('text')),
        isEmpty,
      );
    });

    test('--icon-* colours and sizes land in different classes', () {
      expect(fields('FermanColorTokens'), contains('iconPrimary'));
      expect(fields('FermanDensityTokens'), containsAll(['iconSm', 'iconMd']));
    });

    test('--border-* colours and widths land in different classes', () {
      expect(fields('FermanColorTokens'), contains('borderSubtle'));
      expect(fields('FermanBorderTokens'), [
        'borderWidth',
        'borderWidthStrong',
      ]);
    });
  });

  group('coverage', () {
    test('every token name becomes exactly one field', () {
      final sources = <String>[
        for (final dartClass in model.classes)
          for (final field in dartClass.fields)
            if (!field.name.startsWith('height') ||
                dartClass.name != 'FermanTypeTokens')
              ...field.cssNames,
      ];
      expect(sources.toSet(), hasLength(sources.length));
      expect(sources.toSet(), model.cascade.names.toSet());
    });

    test('on-page marks and ramps do not change in dark', () {
      for (final className in ['FermanRampTokens', 'FermanPageColorTokens']) {
        for (final field in model.classNamed(className).fields) {
          final token = model.tokens[field.cssNames.single]!;
          expect(token.variesIn, isEmpty, reason: field.name);
        }
      }
    });

    test('fields are sorted naturally', () {
      for (final dartClass in model.classes) {
        final names = dartClass.fields.map((f) => f.name).toList();
        expect(names, [...names]..sort(naturalCompare), reason: dartClass.name);
      }
    });
  });

  group('colour placement', () {
    List<String> fields(TokenModel model, String className) =>
        model.classNamed(className).fields.map((f) => f.name).toList();

    test('a colour dark redeclares, even to the same value, is themed', () {
      final model = modelFromCss({
        't.css':
            ':root { --surface-x: #ffffff; } '
            '[data-theme="dark"] { --surface-x: #ffffff; }',
      });
      expect(fields(model, 'FermanColorTokens'), ['surfaceX']);
      expect(model.tokens['surface-x']!.isThemeDependent, isTrue);
    });

    test('an alias of a colour that dark redeclares is themed', () {
      final model = modelFromCss({
        't.css':
            ':root { --surface-x: #ffffff; --chip-bg: var(--surface-x); } '
            '[data-theme="dark"] { --surface-x: #000000; }',
      });
      expect(fields(model, 'FermanColorTokens'), ['chipBg', 'surfaceX']);
      expect(
        valueOf(model, 'FermanColorTokens', 'chipBg', 'dark'),
        'Color(0xFF000000)',
      );
    });

    test('a page-mark colour that never changes is a page colour', () {
      final model = modelFromCss({
        't.css': ':root { --search-hit: #ff9f1c; --page-bg: #ffffff; }',
      });
      expect(fields(model, 'FermanPageColorTokens'), ['pageBg', 'searchHit']);
      expect(
        model.classes.map((c) => c.name),
        isNot(contains('FermanColorTokens')),
      );
    });

    test('a colour the same in every theme needs a page-mark name', () {
      expect(
        () => modelFromCss({'t.css': ':root { --toolbar-tint: #eeeeee; }'}),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('--toolbar-tint'),
              contains('not a page-mark name'),
              contains('[data-theme="dark"]'),
            ),
          ),
        ),
      );
    });

    test('every design page colour has a page-mark name', () {
      for (final field
          in designModel.classNamed('FermanPageColorTokens').fields) {
        final name = field.cssNames.single;
        expect(
          name == 'page-bg' || pageMarkColorPrefixes.any(name.startsWith),
          isTrue,
          reason: name,
        );
      }
    });
  });

  group('the build stops on', () {
    Matcher failsWith(String text) => throwsA(
      isA<TokenException>().having((e) => e.message, 'message', contains(text)),
    );

    test('an unresolved var()', () {
      expect(
        () => modelFromCss({'t.css': ':root { --ink-50: var(--nope); }'}),
        failsWith('unresolved var(--nope)'),
      );
    });

    test('a value the classifier cannot type', () {
      expect(
        () => modelFromCss({'t.css': ':root { --mystery: banana split; }'}),
        failsWith('cannot type'),
      );
    });

    test('a token that varies where its class has no instance', () {
      expect(
        () => modelFromCss({
          't.css':
              ':root { --space-1: 4px; } '
              '[data-theme="dark"] { --space-1: 5px; }',
        }),
        failsWith('FermanSpaceTokens, which has no instance'),
      );
    });

    test('two tokens with the same Dart name', () {
      expect(
        () => modelFromCss({'t.css': ':root { --size-x: 1px; --sizeX: 2px; }'}),
        failsWith('comes from both'),
      );
    });

    test('a value that changes type between environments', () {
      expect(
        () => modelFromCss({
          't.css':
              ':root { --surface-x: #fff; } '
              '[data-theme="dark"] { --surface-x: 0 1px 2px #000; }',
        }),
        throwsA(isA<TokenException>()),
      );
    });
  });
}
