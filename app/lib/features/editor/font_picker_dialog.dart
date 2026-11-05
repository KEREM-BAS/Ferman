import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a3-3b's "Choose a font for this block": the candidates missing-glyph
/// step 3 offers for [glyphs], grouped as Embedded in this document,
/// Installed on this computer and Similar fonts included with Ferman, each
/// row with its coverage badge and the closest usable one tagged "Closest
/// match" and selected first. Search narrows the rows by family; the
/// scope is "Missing characters only" ("Whole block" waits, B137). "Use …"
/// draws the characters in the selected font (`DocumentEditor.chooseFont`),
/// Cancel, Close and Escape close it.
///
/// A row of a font that ships with Ferman previews the letters it has in
/// that font; the others show their name and badge only, as the engine
/// renders no preview of a font the app cannot load (G128).
class FontPickerDialog extends ConsumerStatefulWidget {
  /// The picker for [glyphs].
  const new({required this.glyphs, super.key});

  /// The characters and candidates.
  final MissingGlyphs glyphs;

  @override
  ConsumerState<FontPickerDialog> createState() => _FontPickerDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MissingGlyphs>('glyphs', glyphs));
  }
}

class _FontPickerDialogState extends ConsumerState<FontPickerDialog> {
  String _query = '';
  late FontCandidate? _selected = widget.glyphs.candidates
      .where((c) => c.usable)
      .firstOrNull;

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  void _close() => _editor.showFontPicker(open: false);

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final glyphs = widget.glyphs;
    final closest = glyphs.candidates.where((c) => c.usable).firstOrNull;
    final query = casing.lower(_query.trim());
    final shown = [
      for (final c in glyphs.candidates)
        if (query.isEmpty || casing.lower(c.family).contains(query)) c,
    ];
    final selected = _selected;
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    return Dialog(
      title: l10n.fontPickerTitle,
      onClose: _close,
      closeLabel: l10n.fontPickerClose,
      cancelAction: Button(
        size: ButtonSize.sm,
        onPressed: _close,
        child: Text(l10n.fontPickerCancel),
      ),
      actions: [
        Button(
          size: ButtonSize.sm,
          variant: ButtonVariant.primary,
          disabled: selected == null,
          onPressed: selected == null
              ? null
              : () => unawaited(_editor.chooseFont(selected)),
          child: Text(l10n.fontPickerUse(bidiIsolate(selected?.family ?? ''))),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space2,
        children: [
          SegmentedControl<bool>(
            semanticLabel: l10n.fontPickerScope,
            fullWidth: true,
            value: false,
            onChanged: (_) {},
            options: [
              SegmentOption(value: false, label: l10n.fontPickerScopeMissing),
              SegmentOption(
                value: true,
                label: l10n.fontPickerScopeBlock,
                disabled: true,
                disabledReason: Feature.fontScopeWholeBlock.disabledReason(
                  context,
                ),
              ),
            ],
          ),
          TextField(
            size: FieldSize.sm,
            icon: IconName.search,
            placeholder: l10n.fontPickerSearch,
            semanticLabel: l10n.fontPickerSearch,
            onChanged: (value) => setState(() => _query = value),
          ),
          if (shown.isEmpty)
            Text(
              query.isEmpty
                  ? l10n.editGlyphNoneTitle
                  : l10n.fontPickerNoMatch(_query.trim()),
              style: theme.typography.caption.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          for (final origin in FontOrigin.values)
            if (shown.where((c) => c.origin == origin).toList() case final rows
                when rows.isNotEmpty)
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: _group(l10n, origin),
                child: Container(
                  decoration: BoxDecoration(border: Border(top: line)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: theme.space.space2,
                          bottom: theme.space.space1,
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            casing.upper(_group(l10n, origin)),
                            style: theme.typography.label.copyWith(
                              color: theme.colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      for (final c in rows)
                        _Row(
                          candidate: c,
                          glyphs: glyphs,
                          closest: identical(c, closest),
                          selected: identical(c, selected),
                          onPressed: c.usable
                              ? () => setState(() => _selected = c)
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _group(AppLocalizations l10n, FontOrigin origin) =>
      switch (origin) {
        FontOrigin.embedded => l10n.fontPickerEmbedded,
        FontOrigin.installed => l10n.fontPickerInstalled,
        FontOrigin.bundled => l10n.fontPickerBundled,
      };
}

/// One candidate: the check while selected, its family, the "Closest
/// match" tag, its coverage badge and, for a font that ships with Ferman,
/// the preview in that font.
class _Row extends ConsumerWidget {
  const new({
    required this.candidate,
    required this.glyphs,
    required this.closest,
    required this.selected,
    required this.onPressed,
  });

  final FontCandidate candidate;
  final MissingGlyphs glyphs;
  final bool closest;
  final bool selected;
  final VoidCallback? onPressed;

  /// a3-3b's 14 px check column.
  static const double checkSize = 14;

  /// a3-3b's preview `font-size: 16px; line-height: 1.4`.
  static const double previewSize = 16;

  /// a3-3b's preview line height.
  static const double previewHeight = 1.4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final c = candidate;
    final chars = quotedChars(glyphs);
    final full = c.covered >= c.needed;
    final coverage = !full
        ? (c.covered == 0
              ? l10n.fontPickerHasNone(chars)
              : l10n.fontPickerHasSome(
                  format.integer(c.covered),
                  format.integer(c.needed),
                ))
        : c.usable
        ? l10n.fontPickerHas(chars)
        : l10n.fontPickerNotEmbeddable;
    final preview = c.origin == FontOrigin.bundled && c.preview.isNotEmpty;
    final gap = theme.space.space2;
    return FermanInteractive(
      onPressed: onPressed,
      selected: selected,
      selectable: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      semanticLabel: [
        c.family,
        if (closest) l10n.fontPickerClosest,
        coverage,
      ].join(', '),
      builder: (context, states, _) => Container(
        padding: EdgeInsetsDirectional.symmetric(vertical: gap),
        color: selected ? theme.colors.surfaceSelected : null,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space1,
            children: [
              Row(
                spacing: gap,
                children: [
                  SizedBox(
                    width: checkSize,
                    child: selected
                        ? Icon(
                            IconName.check,
                            size: checkSize,
                            color: theme.colors.textAccent,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      c.family,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(
                        color: c.usable
                            ? theme.colors.textPrimary
                            : theme.colors.textDisabled,
                      ),
                    ),
                  ),
                  if (closest)
                    Badge(
                      label: l10n.fontPickerClosest,
                      tone: BadgeTone.accent,
                    ),
                  Badge(
                    label: coverage,
                    tone: c.usable ? BadgeTone.success : BadgeTone.warning,
                    icon: c.usable ? IconName.check : IconName.triangleAlert,
                  ),
                ],
              ),
              if (preview)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: checkSize + gap),
                  child: Text(
                    c.preview,
                    textDirection: TextDirection.ltr,
                    locale: const Locale('tr'),
                    style: TextStyle(
                      fontFamily: c.family,
                      fontSize: previewSize,
                      height: previewHeight,
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [glyphs]'s characters, each once in ‘ ’ and isolated for its direction:
/// "‘ğ’", "‘ğ’, ‘Ğ’".
String quotedChars(MissingGlyphs glyphs) =>
    {for (final c in glyphs.chars) c.text}.map(quoted).join(', ');

/// [char] in ‘ ’, isolated for its direction.
String quoted(String char) => '‘${bidiIsolate(char)}’';
