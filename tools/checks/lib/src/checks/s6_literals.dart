import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_allowlist.dart';
import 'package:checks/src/checks/s6_source.dart';

/// S6: widget code outside the design system never hard-codes colours,
/// sizes, radii or durations; it reads the design tokens through
/// `context.ferman` (brief §6, ADR 0012).
///
/// Scope: every hand-written Dart file in `app/lib/` except
/// `app/lib/design/**`, where the tokens are wrapped and the components
/// built, and `app/lib/engine/**`, the services over the engine bridge,
/// which hold no widgets (their timeouts and tile sizes are not design
/// values).
///
/// Rules. A literal is a numeric literal written directly as the argument
/// (`8`, `-2`, `0.5`, `1_000`, `0xFF`); an expression such as `space * 2`
/// or a named constant is not. Zero is allowed everywhere except in
/// colours (`EdgeInsetsDirectional.only(start: 0)`, `Duration.zero` and
/// `SizedBox(width: 0)` are fine):
///
/// - `color`: `Color(<literal>)`, `Color.fromARGB(<literal>, …)`,
///   `Color.fromRGBO(<literal>, …)`, `Color.from(alpha: <literal>, …)`.
/// - `material-color`: `Colors.<name>` and `CupertinoColors.<name>`.
/// - `duration`: `Duration(…)` with a non-zero literal for any unit.
/// - `radius`: `BorderRadius.circular(<n>)`,
///   `BorderRadiusDirectional.circular(<n>)`, `Radius.circular(<n>)` and
///   `Radius.elliptical(…)` with a non-zero literal.
/// - `insets`: `EdgeInsets` or `EdgeInsetsDirectional` `.all`, `.symmetric`,
///   `.only`, `.fromLTRB` or `.fromSTEB` with a non-zero literal argument.
/// - `size`: a named argument of [sizeArguments] with a non-zero literal,
///   in any call (`SizedBox(width: 8)`, `Container(height: 40)`,
///   `BoxConstraints(maxWidth: 320)`, `BorderSide(width: 2)`,
///   `Icon(name, size: 16)`, `Row(spacing: 4)`), and `Size(…)`,
///   `Size.square`, `.fromWidth`, `.fromHeight` or `.fromRadius` with a
///   non-zero literal argument.
/// - `font-size`: a `fontSize: <n>` argument with a non-zero literal; text
///   styles come from the type roles.
/// - `theme-bypass`: a token set that varies read from its generated
///   constant instead of `context.ferman`: `FermanColorTokens`,
///   `FermanElevationTokens`, `FermanFocusTokens`, `FermanDensityTokens`,
///   `FermanMotionTokens`, `FermanTypeRoleTokens` or
///   `FermanPageFilterTokens` followed by `.`, and `FermanTheme.light`,
///   `.dark` or `.forBrightness`. Such code ignores dark mode, touch
///   density, reduced motion or the locale. The constant sets (spacing,
///   radii, sizes, type scale, …) never vary and may be read directly.
final class S6LiteralsCheck implements Check {
  /// Creates the check with [allowlist], by default the reviewed
  /// [s6Allowlist].
  const new({List<S6Allowance>? allowlist})
    : allowlist = allowlist ?? s6Allowlist;

  /// The reviewed exceptions.
  final List<S6Allowance> allowlist;

  /// The folders outside the scope: the design system, where literals are
  /// allowed, and the engine services, which hold no widgets.
  static const exempt = ['app/lib/design/', 'app/lib/engine/'];

  /// The named arguments that take a size in pixels (or, for `height` on a
  /// text style, a line-height factor that comes from the type roles).
  static const sizeArguments = [
    'width',
    'height',
    'dimension',
    'size',
    'minWidth',
    'maxWidth',
    'minHeight',
    'maxHeight',
    'iconSize',
    'strokeWidth',
    'thickness',
    'blurRadius',
    'spreadRadius',
    'letterSpacing',
    'spacing',
    'runSpacing',
    'mainAxisSpacing',
    'crossAxisSpacing',
    'mainAxisExtent',
    'maxCrossAxisExtent',
    'itemExtent',
  ];

  /// The generated token classes whose value depends on the environment
  /// (brightness, density, reduced motion, page filter, locale).
  static const varyingTokenClasses = [
    'FermanColorTokens',
    'FermanElevationTokens',
    'FermanFocusTokens',
    'FermanDensityTokens',
    'FermanMotionTokens',
    'FermanTypeRoleTokens',
    'FermanPageFilterTokens',
  ];

  @override
  String get name => 's6_literals';

  @override
  CheckResult run(CheckContext context) {
    final sources = appSources(
      context,
      include: (path) => !exempt.any(path.startsWith),
    );
    if (sources == null) return CheckResult.skip('$s6Root does not exist yet');
    return s6Result(name, [for (final s in sources) ...findings(s)], allowlist);
  }

  static const _token = 'use a token from context.ferman (ADR 0012)';

  /// The findings in [source].
  static List<S6Finding> findings(DartSource source) {
    final result = <S6Finding>[];
    void add(DartCall call, String rule, String what) =>
        result.add(source.finding(call.offset, rule, '$what; $_token'));

    for (final call in source.calls(r'(?<![\w$])Color\s*\(')) {
      final first = call.positional.firstOrNull;
      if (first != null && first.isNumber) add(call, 'color', 'colour literal');
    }
    for (final call in source.calls(
      r'(?<![\w$])Color\s*\.\s*(fromARGB|fromRGBO)\s*\(',
    )) {
      final first = call.positional.firstOrNull;
      if (first != null && first.isNumber) add(call, 'color', 'colour literal');
    }
    for (final call in source.calls(r'(?<![\w$])Color\s*\.\s*from\s*\(')) {
      if (call.named('alpha')?.isNumber ?? false) {
        add(call, 'color', 'colour literal');
      }
    }
    for (final match in RegExp(
      r'(?<![\w$])(Colors|CupertinoColors)\s*\.\s*[A-Za-z_]\w*',
    ).allMatches(source.code)) {
      result.add(
        source.finding(
          match.start,
          'material-color',
          '${match.group(1)} constant; $_token',
        ),
      );
    }
    for (final call in source.calls(r'(?<![\w$])Duration\s*\(')) {
      if (call.arguments.any((a) => a.name != null && a.isNonZeroNumber)) {
        add(call, 'duration', 'duration literal (use the motion tokens)');
      }
    }
    for (final call in source.calls(
      r'(?<![\w$])(BorderRadius|BorderRadiusDirectional|Radius)\s*\.\s*'
      r'circular\s*\(',
    )) {
      if (call.positional.firstOrNull?.isNonZeroNumber ?? false) {
        add(call, 'radius', 'radius literal');
      }
    }
    for (final call in source.calls(
      r'(?<![\w$])Radius\s*\.\s*elliptical\s*\(',
    )) {
      if (call.arguments.any((a) => a.isNonZeroNumber)) {
        add(call, 'radius', 'radius literal');
      }
    }
    for (final call in source.calls(
      r'(?<![\w$])(EdgeInsets|EdgeInsetsDirectional)\s*\.\s*'
      r'(all|symmetric|only|fromLTRB|fromSTEB)\s*\(',
    )) {
      if (call.arguments.any((a) => a.isNonZeroNumber)) {
        add(call, 'insets', 'padding literal');
      }
    }
    for (final match in _namedArgument(sizeArguments).allMatches(source.code)) {
      if (DartArgument(match.group(1), match.group(2)!).isNonZeroNumber) {
        result.add(
          source.finding(
            match.start,
            'size',
            'size literal (${match.group(1)}); $_token',
          ),
        );
      }
    }
    for (final call in source.calls(
      r'(?<![\w$])Size\s*(?:\.\s*(?:square|fromWidth|fromHeight|fromRadius)'
      r'\s*)?\(',
    )) {
      if (call.arguments.any((a) => a.isNonZeroNumber)) {
        add(call, 'size', 'size literal (Size)');
      }
    }
    for (final match in _namedArgument(const [
      'fontSize',
    ]).allMatches(source.code)) {
      if (DartArgument(match.group(1), match.group(2)!).isNonZeroNumber) {
        result.add(
          source.finding(
            match.start,
            'font-size',
            'font size literal; use a type role from context.ferman.typography',
          ),
        );
      }
    }
    for (final match in _themeBypass.allMatches(source.code)) {
      result.add(
        source.finding(
          match.start,
          'theme-bypass',
          '${match.group(0)!.replaceAll(RegExp(r'\s'), '')} bypasses the '
              'theme; read it from context.ferman, which resolves light and '
              'dark, density, reduced motion and the locale',
        ),
      );
    }
    result.sort((a, b) => a.line.compareTo(b.line));
    return result;
  }

  /// A named argument of [names] (group 1) and its value (group 2): the
  /// name follows `(`, `,` or `{`, so `a ? size : 8` is not one.
  static RegExp _namedArgument(List<String> names) =>
      RegExp(r'(?<=[(,{]\s*)(' + names.join('|') + r')\s*:\s*([^,)\]}]+)');

  static final _themeBypass = RegExp(
    r'(?<![\w$])(?:(?:' +
        varyingTokenClasses.join('|') +
        r')\s*\.\s*\w+|FermanTheme\s*\.\s*(?:light|dark|forBrightness)\b)',
  );
}
