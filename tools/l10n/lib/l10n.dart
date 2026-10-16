/// The Ferman isolated-fallback generator (G93).
///
/// Reads the abstract messages of the gen-l10n class in
/// `app/lib/l10n/gen/app_localizations.dart` and writes
/// `app/lib/l10n/isolated_fallback.g.dart`: the English strings wrapped in
/// left-to-right isolates, for a right-to-left app language without a
/// translation.
library;

export 'src/cli.dart'
    show exitError, exitStale, exitUsage, runL10nCli, writeCommand;
export 'src/emitter.dart'
    show emitIsolatedFallback, generatedClass, generatedHeader, reservedNames;
export 'src/errors.dart' show L10nException;
export 'src/generator.dart'
    show
        formatDart,
        generateIsolatedFallback,
        inputPath,
        loadMessages,
        localizationsClass,
        outputPath;
export 'src/masked_source.dart' show MaskedSource, matchingBracket;
export 'src/messages.dart'
    show Message, Parameter, ParameterKind, parseMessages, parseParameters;
