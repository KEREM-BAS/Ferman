import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/features/settings/phone_settings.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Editing pane of Settings, board a11-1c, with the Saving group of G43.
///
/// Mark edited text works and is stored; the canvas follows it. What a
/// missing character does (G36), the reflow switch and "Save a recovery copy
/// every minute" work and are stored too, and the engine follows them
/// (`documentEditorProvider`). Font for new text (B042) and Keep versions
/// (B060) are drawn and disabled through the feature registry. There is no
/// overflow default and no switch for the signed-document warning (G43).
///
/// The Saving group explains saving, and names the folder of the recovery
/// copies with Show in Finder or its likes; the web has no such folder.
class EditingPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  /// The gap between the groups (`gap: 18px`).
  static const double groupGap = 18;

  /// The sample's padding (`padding: 12px 16px 12px 30px`): top and bottom …
  static const double samplePaddingY = 12;

  /// … the end …
  static const double samplePaddingEnd = 16;

  /// … and the start, past the margin bar.
  static const double samplePaddingStart = 30;

  /// The margin bar's width (`width: 2px`).
  static const double sampleBarWidth = 2;

  /// The margin bar's height (`height: 20px`).
  static const double sampleBarHeight = 20;

  /// The margin bar's top (`top: 14px`).
  static const double sampleBarTop = 14;

  /// The sample's size (`font: 400 14px/1.6`).
  static const double sampleSize = 14;

  /// The sample's line height.
  static const double sampleHeight = 1.6;

  /// The note's padding (`padding: 12px 14px`), horizontally.
  static const double notePaddingX = 14;

  /// The note's gap (`gap: 12px`) and its padding vertically.
  static const double noteGap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final caption = typography.caption.copyWith(color: colors.textSecondary);
    final folder = ref.watch(engineServiceProvider).recoveryRoot;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
    final phone = WindowMetrics.isPhone(context);
    Widget target(Widget control) =>
        phone ? PhoneHitTarget(child: control) : control;
    final fontForNewText = Select<String>(
      label: l10n.settingsFontForNewText,
      size: FieldSize.sm,
      value: 'match',
      options: [
        SelectOption(value: 'match', label: l10n.settingsFontForNewTextMatch),
      ],
      disabled: true,
      disabledReason: Feature.addingTextBoxes.disabledReason(context),
    );
    final keepVersions = Select<String>(
      label: l10n.settingsKeepVersions,
      size: FieldSize.sm,
      value: '30',
      options: [SelectOption(value: '30', label: l10n.settingsKeepVersions30)],
      disabled: true,
      disabledReason: Feature.versionHistory.disabledReason(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: groupGap,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space2,
          children: [
            target(
              Switch(
                value: settings.markEdited,
                label: l10n.settingsEditMarks,
                onChanged: (value) => unawaited(
                  changeSetting(
                    ref,
                    (current) => current.copyWith(markEdited: value),
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    samplePaddingStart,
                    samplePaddingY,
                    samplePaddingEnd,
                    samplePaddingY,
                  ),
                  decoration: BoxDecoration(
                    color: theme.ramps.paper0,
                    borderRadius: radius,
                    border: Border.all(
                      color: colors.borderDefault,
                      width: theme.border.borderWidth,
                    ),
                  ),
                  // The board's sample, a Turkish document in every language.
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PositionedDirectional(
                        start: samplePaddingEnd - samplePaddingStart,
                        top: sampleBarTop - samplePaddingY,
                        child: Container(
                          width: sampleBarWidth,
                          height: sampleBarHeight,
                          color: theme.pageColors.editMark,
                        ),
                      ),
                      Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'Kira bedeli '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: PageMark(
                                kind: PageMarkKind.edited,
                                child: TextSpan(text: '19.500 TL'),
                              ),
                            ),
                            TextSpan(text: ' olarak belirlenmiştir.'),
                          ],
                        ),
                        style: TextStyle(
                          fontFamily: theme.typeScale.fontDocSample.family,
                          fontFamilyFallback:
                              theme.typeScale.fontDocSample.fallback,
                          fontSize: sampleSize,
                          height: sampleHeight,
                          color: theme.ramps.paper900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Text(l10n.settingsEditMarksNote, style: caption),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2,
          children: [
            Field.labelOf(context, l10n.settingsMissingGlyphs),
            for (final (value, label) in [
              (MissingGlyphPolicy.similar, l10n.settingsMissingGlyphsSimilar),
              (MissingGlyphPolicy.ask, l10n.settingsMissingGlyphsAsk),
              (MissingGlyphPolicy.mark, l10n.settingsMissingGlyphsMark),
            ])
              target(
                Radio<MissingGlyphPolicy>(
                  value: value,
                  groupValue: settings.missingGlyphs,
                  label: label,
                  onChanged: (policy) => unawaited(
                    changeSetting(
                      ref,
                      (current) => current.copyWith(missingGlyphs: policy),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (phone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space3,
            children: [fontForNewText, keepVersions],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space3,
            children: [
              Expanded(child: fontForNewText),
              Expanded(child: keepVersions),
            ],
          ),
        target(
          Switch(
            value: settings.reflow,
            label: l10n.settingsReflow,
            onChanged: (enabled) => unawaited(
              changeSetting(
                ref,
                (current) => current.copyWith(reflow: enabled),
              ),
            ),
          ),
        ),
        target(
          Switch(
            value: settings.recoveryCopies,
            label: l10n.settingsRecoveryCopies,
            onChanged: (enabled) => unawaited(
              changeSetting(
                ref,
                (current) => current.copyWith(recoveryCopies: enabled),
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsetsDirectional.only(top: theme.space.space4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colors.borderSubtle,
                width: theme.border.borderWidth,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: noteGap,
            children: [
              Field.labelOf(context, l10n.settingsSaving),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: notePaddingX,
                  vertical: noteGap,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusMd),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: noteGap,
                  children: [
                    Icon(IconName.save, color: colors.iconSecondary),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: theme.space.space0_5,
                        children: [
                          Text(
                            l10n.settingsSavingEnd,
                            style: typography.bodyStrong,
                          ),
                          Text(l10n.settingsSavingEndBody, style: caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.space.space0_5,
                children: [
                  Text(l10n.settingsOptimize, style: typography.body),
                  Text(l10n.settingsOptimizeBody, style: caption),
                ],
              ),
              Row(
                spacing: noteGap,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: theme.space.space0_5,
                      children: [
                        Text(
                          l10n.settingsRecoveryFolder,
                          style: typography.body,
                        ),
                        if (folder != null)
                          Text(
                            folder,
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.mono.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (folder != null)
                    Button(
                      size: ButtonSize.sm,
                      icon: IconName.folderOpen,
                      onPressed: () =>
                          unawaited(ref.read(fileAccessProvider).show(folder)),
                      child: Text(switch (ref.watch(shortcutPlatformProvider)) {
                        ShortcutPlatform.mac => l10n.openShowInFinder,
                        ShortcutPlatform.windows => l10n.openShowInExplorer,
                        ShortcutPlatform.linux => l10n.openShowInFolder,
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
