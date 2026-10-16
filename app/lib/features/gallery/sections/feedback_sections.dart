import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;

/// `Banner`: every tone as a box and as a bar.
Widget bannerSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  (String?, String) copy(BannerTone tone) => switch (tone) {
    BannerTone.info => (null, GallerySamples.bannerInfo),
    BannerTone.success => (
      GallerySamples.bannerSuccessTitle,
      GallerySamples.bannerSuccess,
    ),
    BannerTone.warning => (null, GallerySamples.bannerWarning),
    BannerTone.danger => (
      GallerySamples.bannerDangerTitle,
      GallerySamples.bannerDanger,
    ),
    BannerTone.neutral => (null, GallerySamples.bannerNeutral),
  };
  (String, String, IconName) barCopy(BannerTone tone) => switch (tone) {
    BannerTone.warning => (
      GallerySamples.bannerBarWarningTitle,
      GallerySamples.bannerBarWarning,
      IconName.refreshCw,
    ),
    _ => (
      GallerySamples.bannerBarTitle,
      GallerySamples.bannerBar,
      IconName.textCursorInput,
    ),
  };
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.named(
          GalleryLabels.variant,
          BannerVariant.box.name,
        ),
        children: [
          for (final tone in BannerTone.values)
            GallerySpecimen(
              label: tone.name,
              width: theme.size.panelW,
              child: Banner(
                tone: tone,
                title: copy(tone).$1,
                child: Text(copy(tone).$2),
              ),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.named(
          GalleryLabels.variant,
          BannerVariant.bar.name,
        ),
        children: [
          for (final tone in BannerTone.values)
            GallerySpecimen(
              label: tone.name,
              width: theme.size.paletteW,
              child: Banner(
                tone: tone,
                variant: BannerVariant.bar,
                icon: barCopy(tone).$3,
                title: barCopy(tone).$1,
                actions: [
                  Button(
                    size: ButtonSize.sm,
                    onPressed: () {},
                    child: Text(
                      tone == BannerTone.warning
                          ? GallerySamples.reload
                          : l10n.shellToolFillFields,
                    ),
                  ),
                ],
                onDismiss: () {},
                dismissLabel: GallerySamples.dismiss,
                child: Text(barCopy(tone).$2),
              ),
            ),
        ],
      ),
    ],
  );
}

/// `ProgressBar`: determinate and indeterminate, every tone and size.
Widget progressBarSection(BuildContext context) {
  final theme = context.ferman;
  final format = RegionFormat.forRegion(GalleryEnvironment.of(context).region);
  const value = 0.62;
  return GalleryBody(
    children: [
      for (final size in ProgressSize.values)
        GalleryRow(
          label: GalleryLabels.named(GalleryLabels.size, size.name),
          children: [
            for (final tone in ProgressTone.values)
              GallerySpecimen(
                label: GalleryLabels.both(SpecName.determinate.name, tone.name),
                width: theme.size.panelW,
                child: ProgressBar(
                  value: value,
                  tone: tone,
                  size: size,
                  label: GallerySamples.recognizingText,
                  showValue: true,
                  valueText: format.percent(value),
                ),
              ),
            GallerySpecimen(
              label: GalleryLabels.indeterminate,
              width: theme.size.panelW,
              child: ProgressBar(indeterminate: true, size: size),
            ),
          ],
        ),
    ],
  );
}

/// `Spinner`: three sizes, and on the accent.
Widget spinnerSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  return GalleryRow(
    label: GalleryLabels.size,
    children: [
      for (final size in [
        theme.space.space3,
        Spinner.defaultSize,
        theme.space.space8,
      ])
        GallerySpecimen(
          label: GalleryLabels.pixels(size),
          child: Spinner(size: size, semanticLabel: l10n.shellOpening),
        ),
      GallerySpecimen(
        label: SpecName.onAccent.name,
        child: GallerySurface(
          color: theme.colors.accent,
          child: const Spinner(onAccent: true),
        ),
      ),
    ],
  );
}

/// `TaskProgress`: every state as a card and inline.
Widget taskProgressSection(BuildContext context) {
  Widget task(TaskState state, TaskProgressVariant variant) {
    final (title, detail, icon, value) = switch (state) {
      TaskState.running => (
        GallerySamples.recognizingText,
        GallerySamples.taskRunningDetail,
        IconName.scanText,
        0.22,
      ),
      TaskState.paused => (
        GallerySamples.taskPausedTitle,
        GallerySamples.taskPausedDetail,
        IconName.workflow,
        0.43,
      ),
      TaskState.done => (
        GallerySamples.taskDoneTitle,
        GallerySamples.taskDoneDetail,
        IconName.minimize2,
        1.0,
      ),
      TaskState.error => (
        GallerySamples.taskErrorTitle,
        GallerySamples.taskErrorDetail,
        IconName.refreshCw,
        null,
      ),
    };
    return TaskProgress(
      title: title,
      detail: detail,
      icon: icon,
      value: value,
      state: state,
      variant: variant,
      onCancel: () {},
      onPause: () {},
      onResume: () {},
      cancelLabel: GallerySamples.cancel,
      pauseLabel: GallerySamples.pause,
      resumeLabel: GallerySamples.resume,
      primaryAction: state == TaskState.done
          ? (label: GallerySamples.showInFolder, onPressed: () {})
          : null,
    );
  }

  return GalleryBody(
    children: [
      for (final variant in TaskProgressVariant.values)
        GalleryRow(
          label: GalleryLabels.named(GalleryLabels.variant, variant.name),
          children: [
            for (final state in TaskState.values)
              GallerySpecimen(label: state.name, child: task(state, variant)),
          ],
        ),
    ],
  );
}

/// `Toast`: every tone, and with an action.
Widget toastSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  (String, String) copy(ToastTone tone) => switch (tone) {
    ToastTone.neutral => (
      GallerySamples.toastSavedTitle,
      GallerySamples.toastSavedMessage,
    ),
    ToastTone.success => (
      GallerySamples.toastSignatureTitle,
      GallerySamples.toastSignatureMessage,
    ),
    ToastTone.warning => (
      GallerySamples.toastPageTitle,
      GallerySamples.toastPageMessage,
    ),
    ToastTone.danger => (
      GallerySamples.toastErrorTitle,
      GallerySamples.toastErrorMessage,
    ),
  };
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.tone,
        children: [
          for (final tone in ToastTone.values)
            GallerySpecimen(
              label: tone.name,
              child: Toast(
                tone: tone,
                title: copy(tone).$1,
                message: copy(tone).$2,
                onClose: () {},
                closeLabel: l10n.windowClose,
              ),
            ),
        ],
      ),
      GalleryRow(
        label: SpecName.action.name,
        children: [
          GallerySpecimen(
            label: SpecName.action.name,
            child: Toast(
              title: GallerySamples.toastDeletedTitle,
              action: (label: l10n.shellUndo, onPressed: () {}),
              onClose: () {},
              closeLabel: l10n.windowClose,
            ),
          ),
        ],
      ),
    ],
  );
}
