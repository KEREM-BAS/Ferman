/// The Ferman design token generator (ADR 0012).
///
/// Reads the CSS custom properties in `design/` and writes
/// `app/lib/design/tokens.g.dart`.
library;

export 'src/cascade.dart'
    show TokenCascade, TokenEnvironment, TokenSource, tokenSources;
export 'src/classifier.dart' show classifyToken;
export 'src/cli.dart'
    show exitError, exitStale, exitUsage, runTokensCli, writeCommand;
export 'src/color.dart' show alphaByte, argbHex, parseCssColor;
export 'src/color_matrix.dart' show composeColorMatrix;
export 'src/css.dart'
    show
        CssDeclaration,
        CssRule,
        CssStylesheet,
        SourceLocation,
        parseStylesheet;
export 'src/dart_model.dart' show DartClass, DartField, DartInstance;
export 'src/emitter.dart' show emitDart, generatedHeader;
export 'src/errors.dart' show TokenException;
export 'src/generator.dart'
    show formatDart, generateTokens, loadCascade, loadModel, outputPath;
export 'src/mappers.dart'
    show bundledFontFamilies, flutterBlurRadius, mapValue, splitFontStack;
export 'src/model.dart'
    show TokenAxis, TokenInfo, TokenModel, pageMarkColorPrefixes;
export 'src/naming.dart' show camelCase, naturalCompare;
export 'src/pubspec_fonts.dart'
    show
        appPubspecPath,
        declaredFontFamilies,
        fontFamilyProblems,
        referencedFontFamilies;
export 'src/resolver.dart' show VarResolver;
export 'src/supplement.dart' show HatchSpec, Supplement, hatchExpression;
export 'src/values.dart';
