/// The Ferman localization tools.
///
/// The isolated-fallback generator (G93) reads the abstract messages of the
/// gen-l10n class in `app/lib/l10n/gen/app_localizations.dart` and writes
/// `app/lib/l10n/isolated_fallback.g.dart`: the English strings wrapped in
/// left-to-right isolates, for a right-to-left app language without a
/// translation. The review table renders every message of the ARB files into
/// `docs/TRANSLATION_REVIEW.md` for the native-speaker review.
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
export 'src/review_table.dart'
    show
        ArbFile,
        arbDirectory,
        generateReviewDoc,
        languageNames,
        loadArbFiles,
        markdownCell,
        missingCell,
        parseArb,
        renderReviewTable,
        replaceReviewRegion,
        reviewBeginMarker,
        reviewDocPath,
        reviewEndMarker,
        templateArbFile;
export 'src/review_table_cli.dart' show reviewTableCommand, runReviewTableCli;
export 'src/root.dart' show findRepoRoot;
