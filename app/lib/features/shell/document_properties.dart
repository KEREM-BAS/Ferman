import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A document's facts as FmDocPanel and a2-7 write them, in the UI language
/// with the region's numbers, dates and unit.
@immutable
final class DocumentFacts {
  /// The facts of [tab], whose engine document is [document].
  const new({
    required this.l10n,
    required this.format,
    required this.unit,
    required this.tab,
    required this.document,
    this.home,
  });

  /// The facts of the tab [tab] in [context].
  factory of(BuildContext context, WidgetRef ref, ShellDocument tab) {
    final region = ref.watch(regionProvider);
    return DocumentFacts(
      l10n: AppLocalizations.of(context),
      format: RegionFormat.forRegion(region.region),
      unit: region.lengthUnit,
      tab: tab,
      document: tab.document!,
      home: ref.watch(homeDirectoryProvider),
    );
  }

  /// The strings.
  final AppLocalizations l10n;

  /// The region's formats.
  final RegionFormat format;

  /// The region's length unit.
  final LengthUnit unit;

  /// The document's tab.
  final ShellDocument tab;

  /// The engine's document.
  final OpenedDocument document;

  /// The home directory, shown as "~".
  final String? home;

  /// How far a page may be from a paper size and still be named after it,
  /// in points: files write A4 as 595 × 842.
  static const double _paperTolerance = 1;

  /// The Acrobat version that introduced each PDF version (a2-7's "1.7
  /// (Acrobat 8.x)").
  static const Map<String, String> _acrobat = {
    '1.0': '1',
    '1.1': '2',
    '1.2': '3',
    '1.3': '4',
    '1.4': '5',
    '1.5': '6',
    '1.6': '7',
    '1.7': '8',
  };

  /// [value], or "None" when the file gives none.
  String orNone(String? value) =>
      value == null || value.trim().isEmpty ? l10n.propertiesNone : value;

  /// The page count.
  String get pages => format.integer(document.pages.length);

  /// The first page's size: "A4 · 210 × 297 mm", or only the size when it
  /// is no paper size.
  String get pageSize {
    if (document.pages.isEmpty) return l10n.propertiesNone;
    final page = document.pages.first;
    for (final paper in PaperSize.values) {
      final portrait =
          (page.width - paper.widthPoints).abs() <= _paperTolerance &&
          (page.height - paper.heightPoints).abs() <= _paperTolerance;
      final landscape =
          (page.width - paper.heightPoints).abs() <= _paperTolerance &&
          (page.height - paper.widthPoints).abs() <= _paperTolerance;
      if (!portrait && !landscape) continue;
      final name = switch (paper) {
        PaperSize.a4 => l10n.regionPaperA4,
        PaperSize.letter => l10n.regionPaperLetter,
      };
      final size = portrait
          ? format.paperSize(paper, unit)
          : format.dimensions(
              page.width,
              page.height,
              unit,
              maxFractionDigits: switch (unit) {
                LengthUnit.millimetre || LengthUnit.point => 0,
                LengthUnit.centimetre => 1,
                LengthUnit.inch => 2,
              },
            );
      return '$name · $size';
    }
    return format.dimensions(page.width, page.height, unit);
  }

  /// The file's size.
  String get fileSize => format.fileSize(document.fileSize);

  /// The PDF version, as the panel shows it: "1.7".
  String get version => orNone(document.version);

  /// The PDF version with the Acrobat version that introduced it, as a2-7
  /// shows it.
  String get versionWithAcrobat {
    final acrobat = _acrobat[document.version];
    return acrobat == null
        ? version
        : l10n.propertiesVersionAcrobat(document.version, acrobat);
  }

  /// The file's path, the home directory shown as "~".
  String get location {
    final path = tab.path;
    if (path == null) return l10n.propertiesNone;
    final home = this.home;
    if (home != null && path.startsWith('$home/')) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  /// [value] as a date and time, or "None".
  String dateTime(DateTime? value) =>
      value == null ? l10n.propertiesNone : format.dateTime(value);

  /// A yes or no.
  String yesNo({required bool value}) =>
      value ? l10n.propertiesYes : l10n.propertiesNo;

  /// The application that wrote the PDF ("LibreOffice 24.8" is a
  /// LibreOffice file's producer; its creator is "Writer").
  String get madeWith =>
      orNone(document.info.producer ?? document.info.creator);

  /// Whether every permission is allowed.
  static bool _allAllowed(DocumentPermissions p) =>
      p.print &&
      p.printHighQuality &&
      p.modify &&
      p.annotate &&
      p.fillForms &&
      p.copy &&
      p.accessibility &&
      p.assemble;

  /// Whether a password guards the document: to open it, or an owner
  /// password behind restrictions.
  bool get hasPassword {
    final security = document.security;
    return security != null &&
        (security.userPasswordRequired || !_allAllowed(security.permissions));
  }

  /// The document's password: "No password", "Password to open" or "Owner
  /// password".
  String get password {
    final security = document.security;
    if (security == null || !hasPassword) return l10n.propertiesNoPassword;
    return security.userPasswordRequired
        ? l10n.propertiesOpenPassword
        : l10n.propertiesOwnerPassword;
  }

  /// The signed signature fields.
  List<Signature> get signed => [
    for (final field in document.signatures)
      if (field.signed) field,
  ];

  /// The signatures: "1 signature", or null when there are none.
  String? get signatures {
    final count = signed.length;
    return count == 0
        ? null
        : l10n.propertiesSignatures(count, format.integer(count));
  }

  /// a2-7's Security row: "No password · 1 signature".
  String get securitySummary => [password, ?signatures].join(' · ');

  /// a2-10b's Encryption row: "AES-256 · owner password".
  String get encryption {
    final security = document.security;
    if (security == null) return l10n.propertiesNone;
    final method = switch (security.method) {
      EncryptionMethod.rc4 => l10n.propertiesRc4(
        format.integer(security.keyBits),
      ),
      EncryptionMethod.aes128 => l10n.propertiesAes128,
      EncryptionMethod.aes256 => l10n.propertiesAes256,
      // Encrypted only in name.
      EncryptionMethod.identity => l10n.propertiesNone,
    };
    return _allAllowed(security.permissions)
        ? method
        : '$method · ${l10n.propertiesOwnerPasswordSuffix}';
  }

  /// a2-10b's Password to open row.
  String get openPassword => document.security?.userPasswordRequired ?? false
      ? l10n.propertiesRequired
      : l10n.propertiesNone;
}

/// How a font is in the file, as a badge shows it.
enum FontStatus {
  /// The whole program is in the file.
  embedded,

  /// Only the characters the file uses.
  subset,

  /// Not in the file.
  missing;

  /// The status of [font]. A Type 3 font is drawn by the file itself.
  static FontStatus of(FontEntry font) {
    if (font.kind == FontType.type3) return embedded;
    if (!font.embedded) return missing;
    return font.subset ? subset : embedded;
  }

  /// The badge's tone: amber for a font that cannot take new characters.
  BadgeTone get tone =>
      this == embedded ? BadgeTone.neutral : BadgeTone.warning;
}

/// The right panel's sections for an open document (FmDocPanel): File and
/// Security in every mode but Edit, and the fonts in all of them.
class DocumentPanelSections extends ConsumerWidget {
  /// The sections for [tab].
  const new({required this.tab, required this.edit, super.key});

  /// The document's tab, with its engine document.
  final ShellDocument tab;

  /// Whether the panel is Edit mode's (FmDocPanel `kind="edit"`).
  final bool edit;

  /// FmDocPanel's File grid: `grid-template-columns: 84px …`.
  static const double labelWidth = 84;

  /// FmDocPanel's font note: `padding-inline-start: 22px`.
  static const double noteIndent = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final facts = DocumentFacts.of(context, ref, tab);
    final l10n = facts.l10n;
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final secondary = caption.copyWith(color: theme.colors.textSecondary);
    // Values from the file keep their own direction (bidiIsolate). The
    // path breaks anywhere, as FmDocPanel's `word-break: break-all`.
    Widget row(String label, String value, {bool breakAnywhere = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(label, style: secondary),
        ),
        Expanded(
          child: Text(
            bidiIsolate(
              breakAnywhere ? value.characters.join('\u200B') : value,
            ),
            semanticsLabel: breakAnywhere ? value : null,
            style: caption,
          ),
        ),
      ],
    );
    Widget line(IconName icon, String text, {Color? color}) => Row(
      spacing: theme.space.space2,
      children: [
        Icon(
          icon,
          size: theme.density.iconSm,
          color: color ?? theme.colors.iconSecondary,
        ),
        Expanded(child: Text(text, style: caption)),
      ],
    );
    final signed = facts.signed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!edit)
          PanelSection(
            title: l10n.propertiesFile,
            collapsible: false,
            showTopBorder: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space1_5,
              children: [
                row(l10n.propertiesPages, facts.pages),
                row(l10n.propertiesPageSize, facts.pageSize),
                row(l10n.propertiesFileSize, facts.fileSize),
                row(l10n.propertiesVersion, facts.version),
                row(
                  l10n.propertiesLocation,
                  facts.location,
                  breakAnywhere: true,
                ),
                row(
                  l10n.propertiesModified,
                  facts.dateTime(facts.document.info.modified),
                ),
              ],
            ),
          ),
        PanelSection(
          title: l10n.propertiesFonts,
          showTopBorder: !edit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PanelSection.bodyGap,
            children: [
              if (facts.document.fonts.isEmpty)
                Text(l10n.propertiesNone, style: secondary),
              for (final font in facts.document.fonts)
                _panelFont(context, facts, font),
            ],
          ),
        ),
        if (!edit)
          PanelSection(
            title: l10n.propertiesSecurity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space1_5,
              children: [
                line(
                  facts.hasPassword ? IconName.lock : IconName.lockOpen,
                  facts.password,
                ),
                // Neutral until signatures are checked (a2-14, G31).
                if (signed.isNotEmpty)
                  line(
                    IconName.signature,
                    signed.length == 1 && signed.single.page != null
                        ? l10n.propertiesSignatureOnPage(
                            facts.format.integer(signed.single.page! + 1),
                          )
                        : facts.signatures!,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _panelFont(BuildContext context, DocumentFacts facts, FontEntry font) {
    final theme = context.ferman;
    final l10n = facts.l10n;
    final status = FontStatus.of(font);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space0_5,
      children: [
        Row(
          spacing: theme.space.space2,
          children: [
            Icon(
              IconName.type,
              size: theme.density.iconSm,
              color: theme.colors.iconSecondary,
            ),
            Expanded(
              child: Text(
                font.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
            Badge(
              tone: status.tone,
              label: switch (status) {
                FontStatus.embedded => l10n.propertiesEmbedded,
                FontStatus.subset => l10n.propertiesPartial,
                FontStatus.missing => l10n.propertiesNotEmbedded,
              },
            ),
          ],
        ),
        if (status == FontStatus.subset)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: noteIndent),
            child: Text(
              l10n.propertiesPartialNote,
              style: theme.typography.caption.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ShellDocument>('tab', tab))
      ..add(FlagProperty('edit', value: edit, ifTrue: 'edit'));
  }
}

/// The properties dialog's tabs (a2-7, a2-10b).
enum PropertiesTab {
  /// The metadata and the fonts.
  summary,

  /// The encryption and the permissions.
  security,

  /// The language and the scripts (G100).
  advanced,
}

/// The document properties dialog (a2-7, ⌘D): Summary with the metadata and
/// the fonts, Security with the encryption and each permission (a2-10b,
/// G27), and Advanced with the language and the scripts row (G100).
/// [onUnlock] closes it for the owner-password dialog of a restricted
/// document; [onClose] closes it.
class DocumentPropertiesDialog extends ConsumerStatefulWidget {
  /// The dialog for [tab].
  const new({
    required this.tab,
    required this.onClose,
    required this.onUnlock,
    super.key,
  });

  /// The document's tab, with its engine document.
  final ShellDocument tab;

  /// Closes the dialog.
  final VoidCallback onClose;

  /// Opens the owner-password dialog (G106).
  final VoidCallback onUnlock;

  /// a2-7's label columns: `grid-template-columns: 120px …`.
  static const double summaryLabelWidth = 120;

  /// a2-7's column gap.
  static const double columnGap = 14;

  /// a2-7's Type column: `110px`.
  static const double typeWidth = 110;

  /// a2-7's Status column: `120px`.
  static const double statusWidth = 120;

  /// a2-10b's label column: `160px`.
  static const double securityLabelWidth = 160;

  /// a2-10b's permission row: `min-height: 32px`.
  static const double permissionHeight = 32;

  @override
  ConsumerState<DocumentPropertiesDialog> createState() =>
      _DocumentPropertiesDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ShellDocument>('tab', tab))
      ..add(ObjectFlagProperty<VoidCallback>.has('onClose', onClose))
      ..add(ObjectFlagProperty<VoidCallback>.has('onUnlock', onUnlock));
  }
}

class _DocumentPropertiesDialogState
    extends ConsumerState<DocumentPropertiesDialog> {
  PropertiesTab _tab = PropertiesTab.summary;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final facts = DocumentFacts.of(context, ref, widget.tab);
    final l10n = facts.l10n;
    final restricted = facts.document.security?.restricted ?? false;
    return Dialog(
      size: DialogSize.lg,
      title: l10n.propertiesDialogTitle(bidiIsolate(widget.tab.name)),
      onClose: widget.onClose,
      closeLabel: l10n.propertiesClose,
      footerStart: restricted
          ? Button(
              variant: ButtonVariant.ghost,
              icon: IconName.keyRound,
              onPressed: widget.onUnlock,
              child: Text(l10n.restrictedUnlock),
            )
          : null,
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: widget.onClose,
          child: Text(l10n.propertiesDone),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space4,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedControl<PropertiesTab>(
              semanticLabel: l10n.propertiesSection,
              value: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
              options: [
                SegmentOption(
                  value: PropertiesTab.summary,
                  label: l10n.propertiesSummary,
                ),
                SegmentOption(
                  value: PropertiesTab.security,
                  label: l10n.propertiesSecurity,
                ),
                SegmentOption(
                  value: PropertiesTab.advanced,
                  label: l10n.propertiesAdvanced,
                ),
              ],
            ),
          ),
          ...switch (_tab) {
            PropertiesTab.summary => _summary(context, facts),
            PropertiesTab.security => _security(context, facts),
            PropertiesTab.advanced => [
              _pairs(context, DocumentPropertiesDialog.securityLabelWidth, [
                (
                  l10n.propertiesLanguage,
                  facts.orNone(facts.document.language),
                ),
                (
                  l10n.propertiesScripts,
                  facts.document.scripts == 0
                      ? l10n.propertiesNone
                      : l10n.propertiesScriptsValue(
                          facts.document.scripts,
                          facts.format.integer(facts.document.scripts),
                        ),
                ),
              ]),
            ],
          },
        ],
      ),
    );
  }

  TextStyle _body(BuildContext context) {
    final theme = context.ferman;
    return theme.typography.body.copyWith(
      color: theme.colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// A label and its value.
  Widget _pair(BuildContext context, double width, (String, String) pair) {
    final theme = context.ferman;
    final body = _body(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DocumentPropertiesDialog.columnGap,
      children: [
        SizedBox(
          width: width,
          child: Text(
            pair.$1,
            style: body.copyWith(color: theme.colors.textSecondary),
          ),
        ),
        // Metadata from the file keeps its own direction.
        Expanded(child: Text(bidiIsolate(pair.$2), style: body)),
      ],
    );
  }

  /// One label column and its values.
  Widget _pairs(
    BuildContext context,
    double width,
    List<(String, String)> pairs,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: context.ferman.space.space2,
    children: [for (final pair in pairs) _pair(context, width, pair)],
  );

  /// A table in a2-7's box: a sunken heading and rows with a line above.
  Widget _table(BuildContext context, Widget heading, List<Widget> rows) {
    final theme = context.ferman;
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(line),
        borderRadius: BorderRadius.circular(theme.radius.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: theme.colors.surfaceSunken,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space3,
                vertical: theme.space.space2,
              ),
              child: DefaultTextStyle.merge(
                style: theme.typography.label.copyWith(
                  color: theme.colors.textTertiary,
                ),
                child: heading,
              ),
            ),
          ),
          for (final row in rows)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: line)),
              child: row,
            ),
        ],
      ),
    );
  }

  List<Widget> _summary(BuildContext context, DocumentFacts facts) {
    final theme = context.ferman;
    final l10n = facts.l10n;
    final info = facts.document.info;
    final casing = LocaleCasing.of(context);
    const label = DocumentPropertiesDialog.summaryLabelWidth;
    // a2-7's grid, read row by row: the metadata on the start side, the
    // file's facts on the end side.
    final rows = [
      (
        (l10n.propertiesTitle, facts.orNone(info.title)),
        (l10n.propertiesVersion, facts.versionWithAcrobat),
      ),
      (
        (l10n.propertiesAuthor, facts.orNone(info.author)),
        (l10n.propertiesPageSize, facts.pageSize),
      ),
      (
        (l10n.propertiesSubject, facts.orNone(info.subject)),
        (l10n.propertiesPages, facts.pages),
      ),
      (
        (l10n.propertiesKeywords, facts.orNone(info.keywords)),
        (l10n.propertiesFileSize, facts.fileSize),
      ),
      (
        (l10n.propertiesCreated, facts.dateTime(info.created)),
        (l10n.propertiesTagged, facts.yesNo(value: facts.document.tagged)),
      ),
      (
        (l10n.propertiesModified, facts.dateTime(info.modified)),
        (
          l10n.propertiesFastWebView,
          facts.yesNo(value: facts.document.linearized),
        ),
      ),
      (
        (l10n.propertiesMadeWith, facts.madeWith),
        (l10n.propertiesSecurity, facts.securitySummary),
      ),
    ];
    Widget fontRow(List<Widget> cells) => Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space3,
        vertical: theme.space.space2,
      ),
      child: Row(
        spacing: theme.space.space3,
        children: [
          Expanded(child: cells[0]),
          SizedBox(width: DocumentPropertiesDialog.typeWidth, child: cells[1]),
          SizedBox(
            width: DocumentPropertiesDialog.statusWidth,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: cells[2],
            ),
          ),
        ],
      ),
    );
    final body = _body(context);
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space2,
        children: [
          for (final (start, end) in rows)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DocumentPropertiesDialog.columnGap,
              children: [
                Expanded(child: _pair(context, label, start)),
                Expanded(child: _pair(context, label, end)),
              ],
            ),
        ],
      ),
      if (facts.document.fonts.isNotEmpty)
        _table(
          context,
          Row(
            spacing: theme.space.space3,
            children: [
              Expanded(child: Text(casing.upper(l10n.propertiesFontColumn))),
              SizedBox(
                width: DocumentPropertiesDialog.typeWidth,
                child: Text(casing.upper(l10n.propertiesTypeColumn)),
              ),
              SizedBox(
                width: DocumentPropertiesDialog.statusWidth,
                child: Text(casing.upper(l10n.propertiesStatusColumn)),
              ),
            ],
          ),
          [
            for (final font in facts.document.fonts)
              fontRow([
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(font.name, style: body),
                    if (FontStatus.of(font) == FontStatus.subset)
                      Text(
                        l10n.propertiesSubsetNote,
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.textTertiary,
                        ),
                      ),
                  ],
                ),
                Text(switch (font.kind) {
                  FontType.type1 => l10n.propertiesFontType1,
                  FontType.multipleMaster => l10n.propertiesFontMultipleMaster,
                  FontType.trueType => l10n.propertiesFontTrueType,
                  FontType.type0 => l10n.propertiesFontType0,
                  FontType.type3 => l10n.propertiesFontType3,
                  FontType.other => l10n.propertiesFontOther,
                }, style: body.copyWith(color: theme.colors.textSecondary)),
                switch (FontStatus.of(font)) {
                  FontStatus.embedded => Badge(
                    icon: IconName.check,
                    label: l10n.propertiesEmbedded,
                  ),
                  FontStatus.subset => Badge(
                    tone: BadgeTone.warning,
                    icon: IconName.triangleAlert,
                    label: l10n.propertiesSubset,
                  ),
                  FontStatus.missing => Badge(
                    tone: BadgeTone.warning,
                    icon: IconName.triangleAlert,
                    label: l10n.propertiesNotEmbedded,
                  ),
                },
              ]),
          ],
        ),
    ];
  }

  List<Widget> _security(BuildContext context, DocumentFacts facts) {
    final theme = context.ferman;
    final l10n = facts.l10n;
    final p =
        facts.document.security?.permissions ?? const DocumentPermissions();
    final printing = !p.print
        ? null
        : p.printHighQuality
        ? l10n.propertiesAllowedHighQuality
        : l10n.propertiesAllowed;
    final permissions = [
      (l10n.propertiesPrinting, printing),
      (l10n.propertiesChanging, p.modify ? l10n.propertiesAllowed : null),
      (l10n.propertiesCommenting, p.annotate ? l10n.propertiesAllowed : null),
      (l10n.propertiesFilling, p.fillForms ? l10n.propertiesAllowed : null),
      // Signature fields are form fields (PDF 32000-1 table 22, bit 9).
      (l10n.propertiesSigning, p.fillForms ? l10n.propertiesAllowed : null),
      (l10n.propertiesCopying, p.copy ? l10n.propertiesAllowed : null),
      (
        l10n.propertiesScreenReaders,
        p.accessibility ? l10n.propertiesAllowed : null,
      ),
      (l10n.propertiesAssembling, p.assemble ? l10n.propertiesAllowed : null),
    ];
    final body = _body(context);
    return [
      _pairs(context, DocumentPropertiesDialog.securityLabelWidth, [
        (l10n.propertiesEncryption, facts.encryption),
        (l10n.propertiesOpenPassword, facts.openPassword),
      ]),
      _table(
        context,
        // a2-10b's heading is tracked; a2-7's fonts heading is not.
        Text(
          LocaleCasing.of(context).upper(l10n.propertiesPermissions),
          style: TextStyle(
            letterSpacing:
                theme.typeScale.trackingLabel *
                theme.typography.label.fontSize!,
          ),
        ),
        [
          for (final (name, allowed) in permissions)
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: DocumentPropertiesDialog.permissionHeight,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space3,
                  vertical: theme.space.space1,
                ),
                child: Row(
                  spacing: theme.space.space3,
                  children: [
                    Expanded(child: Text(name, style: body)),
                    // Not allowed is neutral: it describes the file, not an
                    // error (a2-10b).
                    if (allowed == null)
                      Badge(icon: IconName.x, label: l10n.propertiesNotAllowed)
                    else
                      Badge(
                        tone: BadgeTone.success,
                        icon: IconName.check,
                        label: allowed,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }
}
