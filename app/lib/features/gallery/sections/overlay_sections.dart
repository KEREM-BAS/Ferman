import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// `CommandPalette`, inline: open with the UI kit's commands, and with a
/// query that matches nothing.
Widget commandPaletteSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final env = GalleryEnvironment.of(context);
  final groups = <CommandGroup>[
    (
      label: GallerySamples.suggested,
      items: [
        CommandItem(
          id: 'replace',
          label: GallerySamples.findAndReplace,
          icon: IconName.replace,
          hint: GallerySamples.hintEdit,
          shortcut: env.caps(ShellCommand.findAndReplace),
          keywords: GallerySamples.findAndReplaceKeywords,
        ),
        CommandItem(
          id: 'ocr',
          label: l10n.shellToolRecognizeText,
          icon: IconName.scanText,
          hint: GallerySamples.hintConvert,
        ),
        CommandItem(
          id: 'sign',
          label: GallerySamples.addSignature,
          icon: IconName.signature,
          hint: GallerySamples.hintSign,
          keywords: GallerySamples.addSignatureKeywords,
          disabledReason: futureVersionReason(context),
        ),
        const CommandItem(
          id: 'redact',
          label: GallerySamples.redactText,
          icon: IconName.eyeOff,
          hint: GallerySamples.hintProtect,
          keywords: GallerySamples.redactKeywords,
        ),
      ],
    ),
    (
      label: GallerySamples.modes,
      items: [
        for (final mode in FermanMode.values.take(3))
          CommandItem(
            id: 'mode-${mode.id}',
            label: GallerySamples.goTo(l10n.modeLabel(mode)),
            icon: mode.icon,
          ),
      ],
    ),
    (
      label: GallerySamples.file,
      items: [
        CommandItem(
          id: 'save',
          label: l10n.shellSave,
          icon: IconName.save,
          shortcut: env.caps(ShellCommand.save),
        ),
        CommandItem(
          id: 'close',
          label: l10n.shellCloseDocument,
          icon: IconName.x,
          shortcut: env.caps(ShellCommand.closeDocument),
        ),
      ],
    ),
  ];
  const footer = <CommandFooterHint>[
    (keys: GallerySamples.moveKeys, label: GallerySamples.move),
    (keys: GallerySamples.runKeys, label: GallerySamples.run),
    (keys: [GallerySamples.esc], label: GallerySamples.close),
  ];
  Widget palette({String? query}) => CommandPalette(
    inline: true,
    groups: groups,
    query: query,
    placeholder: GallerySamples.paletteSearch,
    semanticLabel: GallerySamples.commandPalette,
    emptyText: query == null ? null : GallerySamples.paletteEmpty(query),
    escapeKeys: const [GallerySamples.esc],
    footerHints: footer,
    onSelected: (_) {},
    onClose: () {},
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(label: GalleryLabels.open, child: palette()),
      GallerySpecimen(
        label: SpecName.empty.name,
        child: palette(query: GallerySamples.paletteNoMatchQuery),
      ),
      GallerySpecimen(
        label: GalleryLabels.focusVisible,
        forced: GalleryForced.focusVisible,
        child: palette(),
      ),
    ],
  );
}

/// `Dialog`, inline: every tone and size, with the boards' copy.
Widget dialogSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  Widget dialog(DialogTone tone, DialogSize size) {
    final (icon, title, description, primary) = switch (tone) {
      DialogTone.standard when size == DialogSize.lg => (
        null,
        GallerySamples.pageLabelsTitle,
        GallerySamples.pageLabelsDescription,
        Button(
          variant: ButtonVariant.primary,
          onPressed: () {},
          child: const Text(GallerySamples.apply),
        ),
      ),
      DialogTone.standard => (
        IconName.save,
        GallerySamples.saveChangesTitle,
        GallerySamples.saveChangesDescription,
        Button(
          variant: ButtonVariant.primary,
          onPressed: () {},
          child: Text(l10n.shellSave),
        ),
      ),
      DialogTone.warning => (
        IconName.hardDrive,
        GallerySamples.diskFullTitle,
        GallerySamples.diskFullDescription,
        Button(
          variant: ButtonVariant.primary,
          onPressed: () {},
          child: const Text(GallerySamples.saveAs),
        ),
      ),
      DialogTone.danger => (
        IconName.eyeOff,
        GallerySamples.applyRedactionsTitle,
        GallerySamples.applyRedactionsDescription,
        Button(
          variant: ButtonVariant.danger,
          onPressed: () {},
          child: const Text(GallerySamples.applyRedactions),
        ),
      ),
    };
    return Dialog(
      inline: true,
      tone: tone,
      size: size,
      icon: icon,
      title: title,
      description: description,
      onClose: () {},
      closeLabel: l10n.windowClose,
      footerStart: tone == DialogTone.standard && size != DialogSize.lg
          ? Button(
              variant: ButtonVariant.ghost,
              onPressed: () {},
              child: const Text(GallerySamples.dontSave),
            )
          : null,
      actions: [
        Button(onPressed: () {}, child: const Text(GallerySamples.cancel)),
        primary,
      ],
    );
  }

  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.tone,
        children: [
          for (final tone in DialogTone.values)
            GallerySpecimen(
              label: tone.name,
              child: dialog(
                tone,
                tone == DialogTone.danger ? DialogSize.sm : DialogSize.md,
              ),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in DialogSize.values)
            GallerySpecimen(
              label: size.name,
              child: dialog(DialogTone.standard, size),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.focusVisible,
        children: [
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: dialog(DialogTone.danger, DialogSize.sm),
          ),
        ],
      ),
    ],
  );
}

/// `Menu`: the Organize page menu with every kind of item.
Widget menuSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final env = GalleryEnvironment.of(context);
  final future = futureVersionReason(context);
  final items = [
    const MenuItem.section(GallerySamples.pageMenu),
    MenuItem(
      id: 'rotate',
      label: l10n.shellToolRotateRight,
      icon: IconName.rotateCw,
      shortcut: env.caps(ShellCommand.rotateRight),
    ),
    MenuItem(
      id: 'dup',
      label: l10n.shellToolDuplicate,
      icon: IconName.copy,
      shortcut: env.caps(ShellCommand.duplicatePages),
    ),
    const MenuItem(
      id: 'extract',
      label: GallerySamples.extractAsNew,
      icon: IconName.fileOutput,
    ),
    MenuItem(
      id: 'insert',
      label: GallerySamples.insertFromFile,
      icon: IconName.filePlus2,
      disabled: true,
      disabledReason: future,
    ),
    const MenuItem.divider(),
    MenuItem(id: 'comments', label: l10n.shellShowComments, checked: true),
    MenuItem(
      id: 'layout',
      label: l10n.shellPageLayout,
      icon: IconName.columns2,
      submenu: [
        MenuItem(id: 'single', label: l10n.shellLayoutSingle, checked: false),
        MenuItem(
          id: 'continuous',
          label: l10n.shellLayoutContinuous,
          checked: true,
        ),
        MenuItem(id: 'spread', label: l10n.shellLayoutTwoPage, checked: false),
      ],
    ),
    const MenuItem.divider(),
    MenuItem(
      id: 'delete',
      label: GallerySamples.deletePage,
      icon: IconName.trash2,
      shortcut: env.caps(ShellCommand.deletePages),
      danger: true,
    ),
  ];
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(
        label: GalleryLabels.open,
        excludeSemantics: true,
        child: Menu(
          items: items,
          semanticLabel: GallerySamples.pageMenu,
          onSelected: (_) {},
          onClose: () {},
        ),
      ),
      GallerySpecimen(
        label: GalleryLabels.both(GalleryLabels.open, GalleryLabels.hover),
        forced: GalleryForced.hover,
        excludeSemantics: true,
        child: Menu(
          items: items.take(4).toList(),
          semanticLabel: GallerySamples.pageMenu,
          onSelected: (_) {},
          onClose: () {},
        ),
      ),
    ],
  );
}

/// `Scrim`: the dialog's and the palette's (top) layer.
Widget scrimSection(BuildContext context) {
  final theme = context.ferman;
  Widget scrim({required bool top}) => SizedBox(
    width: theme.size.dialogWSm,
    height: theme.size.panelW,
    child: Scrim(
      top: top,
      onDismiss: () {},
      dismissLabel: GallerySamples.dismiss,
      child: PopoverSurface(
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.space.space4),
          child: Text(
            top
                ? GallerySamples.paletteSearch
                : GallerySamples.saveChangesTitle,
          ),
        ),
      ),
    ),
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(label: GalleryLabels.standard, child: scrim(top: false)),
      GallerySpecimen(label: SpecName.top.name, child: scrim(top: true)),
    ],
  );
}
