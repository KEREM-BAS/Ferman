/// The Ferman icons tool (ADR 0013).
///
/// Reads the icon geometry from the read-only design export and writes the
/// SVG files, their provenance table, the Lucide licence texts, the
/// generated `IconName` enum and the element data the app paints from. It
/// also renders docs/COMPONENTS.md from the component spec.
library;

export 'src/cli.dart'
    show exitError, exitStale, exitUsage, findRoot, runIconsCli;
export 'src/component_spec.dart'
    show
        beginMarker,
        componentSpecPath,
        componentsDocPath,
        decodeSpec,
        endMarker,
        renderComponentsDoc,
        renderReference,
        runComponentSpecCli;
export 'src/dart_enum.dart'
    show assetsDir, dartIdentifier, emitIconEnum, enumPath;
export 'src/design_icons.dart'
    show
        DesignIcon,
        IconOrigin,
        additionsIconCount,
        additionsPath,
        bundleIconCount,
        bundlePath,
        loadDesignIcons,
        totalIconCount;
export 'src/directional.dart' show directionalIcons;
export 'src/errors.dart' show IconsException;
export 'src/generator.dart'
    show
        Difference,
        IconsOutput,
        compareWithDisk,
        formatDart,
        generateIcons,
        licensePath,
        provenancePath,
        unexpectedSvgs,
        writeOutput;
export 'src/icon_data.dart'
    show
        AttributeKind,
        IconElementData,
        IconElementType,
        dartString,
        dataPath,
        elementPath,
        emitIconData,
        fillAttribute,
        fillValue,
        iconElementTypes,
        iconElements,
        ignoredAttributes;
export 'src/js_literal.dart' show readStringMap;
export 'src/lucide.dart'
    show
        LicenseGroup,
        LucidePackage,
        LucideRelease,
        licenseGroups,
        loadLucide,
        lucideReleases,
        matchIcons,
        readTarGz,
        sriSha512;
export 'src/provenance.dart'
    show
        decodeMatches,
        encodeMatches,
        fermanDesign,
        markupSha256,
        matchesPath,
        renderProvenance,
        sourceLabel;
export 'src/svg.dart'
    show
        SvgElement,
        innerMarkup,
        parseShapes,
        sameGeometry,
        svgCloseTag,
        svgDocumentChildren,
        svgFile,
        svgOpenTag;
export 'src/text.dart' show normalizeNewlines, readText;
