import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/tools/tools_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A Tools panel's frame (a9-1, a9-8): the panel surface with its subtle
/// line on the start side, a 40 px heading with an optional [icon], the
/// [title] and a [trailing] note, and the [child] below.
class ToolsPanelFrame extends StatelessWidget {
  /// The frame.
  const new({
    required this.title,
    required this.child,
    this.width,
    this.icon,
    this.trailing,
    super.key,
  });

  /// The heading's title.
  final String title;

  /// The heading's icon.
  final IconName? icon;

  /// The heading's note at the end.
  final String? trailing;

  /// The width; null takes the panel's.
  final double? width;

  /// The body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      child: Container(
        width: width ?? theme.size.panelW,
        decoration: BoxDecoration(
          color: theme.colors.surfacePanel,
          border: BorderDirectional(start: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: FmDocPanel.headingHeight,
              padding: EdgeInsetsDirectional.only(
                start: theme.space.space3,
                end: theme.space.space1_5,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  if (icon case final icon?)
                    Icon(
                      icon,
                      size: theme.density.iconMd,
                      color: theme.colors.iconSecondary,
                    ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.panelTitle.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (trailing case final trailing?)
                    Text(
                      trailing,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('title', title))
      ..add(EnumProperty<IconName>('icon', icon))
      ..add(StringProperty('trailing', trailing))
      ..add(DoubleProperty('width', width));
  }
}

/// Opens Compress (a9-1): Tools mode with its panel.
void showCompress(WidgetRef ref) {
  ref.read(shellModeProvider.notifier).select(FermanMode.tools);
  ref.read(toolsPanelProvider.notifier).show(ToolsPanel.compress);
  ref.read(shellPanelOpenProvider.notifier).open();
}

/// Asks where to write, then compresses the open document with [preset] as a
/// job (a9-1); [signed] passes the warning the panel showed (decision 25).
Future<void> compressAndSaveAs(
  WidgetRef ref,
  CompressPreset preset, {
  required bool signed,
}) async {
  final document = ref.read(openDocumentProvider);
  final tab = ref.read(shellDocumentsProvider).active;
  if (document == null || tab == null) return;
  final l10n = lookupAppLocalizations(ref.read(appLocaleProvider));
  final stem = tab.name.replaceFirst(
    RegExp(r'\.pdf$', caseSensitive: false),
    '',
  );
  final output = await ref
      .read(filePickerServiceProvider)
      .saveFile(suggestedName: pdfFileName(l10n.compressFileName(stem)));
  if (output == null) return;
  await ref
      .read(backgroundJobsProvider.notifier)
      .compress(
        document.id,
        tab.name,
        preset: preset,
        output: output,
        unsign: signed,
      );
}

/// a9-1's panel: the presets with their estimated size, Now and After, what
/// the preset does, and "Compress and save as…", which writes a new file as
/// a job. Custom… has no form drawn and stays disabled (B182). A signed
/// document says first that the copy has no signatures (decision 25).
class CompressPanel extends ConsumerWidget {
  /// The panel.
  const new({super.key, this.width});

  /// The board's width (`width:320px`).
  static const double boardWidth = 320;

  /// Its width; null takes the panel's.
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final analysis = ref.watch(compressAnalysisProvider);
    final found = analysis.value;
    final preset = ref.watch(compressChoiceProvider);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final caption = theme.typography.caption;
    CompressEstimate? estimateOf(CompressPreset preset) => found?.estimates
        .where((estimate) => estimate.preset == preset)
        .firstOrNull;
    final estimate = estimateOf(preset);
    final ppi = switch (preset) {
      CompressPreset.highQuality => 300,
      CompressPreset.balanced => 150,
      CompressPreset.smallest => 96,
    };
    String name(CompressPreset preset) => switch (preset) {
      CompressPreset.highQuality => l10n.compressHighQuality,
      CompressPreset.balanced => l10n.compressBalanced,
      CompressPreset.smallest => l10n.compressSmallest,
    };

    Widget card({
      required String title,
      required String description,
      String? size,
      bool checked = false,
      VoidCallback? onPressed,
      String? disabledReason,
    }) => Semantics(
      inMutuallyExclusiveGroup: true,
      checked: checked,
      enabled: onPressed != null,
      hint: disabledReason,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space3,
            vertical: theme.space.space2_5,
          ),
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusMd),
            ),
            border: Border.all(
              color: checked ? theme.colors.accent : theme.colors.borderSubtle,
              width: checked
                  ? theme.border.borderWidth * 2
                  : theme.border.borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space0_5,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.typography.bodyStrong.copyWith(
                        color: onPressed == null
                            ? theme.colors.textDisabled
                            : theme.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (size != null)
                    Text(
                      size,
                      style: theme.typography.bodyStrong.copyWith(
                        color: theme.colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              Text(
                description,
                style: caption.copyWith(color: theme.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );

    Widget does(IconName icon, String text, {bool kept = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        Icon(
          icon,
          size: theme.density.iconSm,
          color: kept ? theme.colors.successSolid : theme.colors.iconSecondary,
        ),
        Expanded(
          child: Text(
            text,
            style: caption.copyWith(color: theme.colors.textPrimary),
          ),
        ),
      ],
    );

    Widget bar(double fill, {required bool now}) => Container(
      height: theme.space.space2,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: now ? theme.colors.borderStrong : theme.colors.surfaceSunken,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusXs)),
      ),
      child: now
          ? null
          : FractionallySizedBox(
              widthFactor: fill.clamp(0, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.accent,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusXs),
                  ),
                ),
              ),
            ),
    );

    final left = found == null
        ? 0
        : found.unreadable + found.masks + found.patterns;
    final numbers = caption.copyWith(
      color: theme.colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ToolsPanelFrame(
      title: l10n.compressTitle,
      icon: IconName.minimize2,
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    label: l10n.compressPreset,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(theme.space.space3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space1_5,
                        children: [
                          for (final each in CompressPreset.values)
                            card(
                              title: name(each),
                              description: switch (each) {
                                CompressPreset.highQuality =>
                                  l10n.compressHighQualityDescription,
                                CompressPreset.balanced =>
                                  l10n.compressBalancedDescription,
                                CompressPreset.smallest =>
                                  l10n.compressSmallestDescription,
                              },
                              size: switch (estimateOf(each)) {
                                final estimate? => l10n.compressAbout(
                                  format.fileSize(estimate.after),
                                ),
                                null => null,
                              },
                              checked: each == preset,
                              onPressed: () => ref
                                  .read(compressChoiceProvider.notifier)
                                  .pick(each),
                            ),
                          card(
                            title: l10n.compressCustom,
                            description: l10n.compressCustomDescription,
                            disabledReason: Feature.compressCustom
                                .disabledReason(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (found != null)
                    Container(
                      padding: EdgeInsetsDirectional.only(
                        start: theme.space.space3,
                        end: theme.space.space3,
                        bottom: theme.space.space3,
                      ),
                      decoration: BoxDecoration(border: Border(bottom: line)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space2,
                        children: [
                          Row(
                            spacing: theme.space.space2,
                            children: [
                              SizedBox(
                                width: _CompressLayout.labelWidth,
                                child: Text(l10n.compressNow, style: numbers),
                              ),
                              Expanded(child: bar(1, now: true)),
                              SizedBox(
                                width: _CompressLayout.sizeWidth,
                                child: Text(
                                  format.fileSize(found.before),
                                  textAlign: TextAlign.end,
                                  style: numbers.copyWith(
                                    color: theme.colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            spacing: theme.space.space2,
                            children: [
                              SizedBox(
                                width: _CompressLayout.labelWidth,
                                child: Text(l10n.compressAfter, style: numbers),
                              ),
                              Expanded(
                                child: bar(
                                  found.before == 0 || estimate == null
                                      ? 0
                                      : estimate.after / found.before,
                                  now: false,
                                ),
                              ),
                              SizedBox(
                                width: _CompressLayout.sizeWidth,
                                child: Text(
                                  estimate == null
                                      ? ''
                                      : l10n.compressAbout(
                                          format.fileSize(estimate.after),
                                        ),
                                  textAlign: TextAlign.end,
                                  style: numbers.copyWith(
                                    color: theme.colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            estimate == null || estimate.exact
                                ? l10n.compressEstimateExact
                                : l10n.compressEstimateSampled(
                                    estimate.sampled,
                                    format.integer(estimate.sampled),
                                  ),
                            style: caption.copyWith(
                              color: theme.colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (found != null)
                    PanelSection(
                      title: l10n.compressDoes(name(preset)),
                      collapsible: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space2,
                        children: [
                          if (found.images > 0)
                            does(
                              IconName.image,
                              l10n.compressDoesImages(
                                found.images,
                                format.integer(found.images),
                                format.integer(ppi),
                              ),
                            ),
                          if (found.duplicateFonts > 0)
                            does(
                              IconName.type,
                              l10n.compressDoesFonts(
                                found.duplicateFonts,
                                format.integer(found.duplicateFonts),
                              ),
                            ),
                          does(IconName.trash2, l10n.compressDoesUnused),
                          if (left > 0)
                            does(
                              IconName.info,
                              l10n.compressDoesLeft(left, format.integer(left)),
                            ),
                          does(
                            IconName.check,
                            l10n.compressDoesKeeps,
                            kept: true,
                          ),
                        ],
                      ),
                    ),
                  if (found?.signed ?? false)
                    Padding(
                      padding: EdgeInsetsDirectional.all(theme.space.space3),
                      child: Banner(
                        tone: BannerTone.warning,
                        title: l10n.compressSignedTitle,
                        child: Text(l10n.compressSignedBody),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsetsDirectional.all(theme.space.space3),
            decoration: BoxDecoration(border: Border(top: line)),
            child: Button(
              variant: ButtonVariant.primary,
              icon: IconName.minimize2,
              fullWidth: true,
              // Unknown counts as not signed: the engine refuses a signed file
              // without the warning.
              onPressed: analysis.isLoading
                  ? null
                  : () => unawaited(
                      compressAndSaveAs(
                        ref,
                        preset,
                        signed: found?.signed ?? false,
                      ),
                    ),
              child: Text(l10n.compressAction),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

/// a9-1's measures that are not tokens.
abstract final class _CompressLayout {
  /// Now and After (`grid-template-columns:52px …`).
  static const double labelWidth = 52;

  /// The sizes (`… 64px`).
  static const double sizeWidth = 64;
}
