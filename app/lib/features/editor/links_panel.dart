import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a3-6's Links panel, in the right panel's place while the Link tool is on:
/// the heading with the count and Add link, every link of the document, broken
/// ones marked, and the note that Ferman asks before a link leaves it.
class LinksPanel extends ConsumerWidget {
  /// The panel.
  const new({super.key, this.width});

  /// Its width; null takes the design's.
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final list = ref.watch(documentLinksProvider).value;
    final links = list?.links ?? const <LinkInfo>[];
    final selected = ref.watch(linkToolProvider.select((s) => s.selected));
    final refusal = ref.watch(linkRefusalProvider);
    final selection = ref.watch(canvasSelectionProvider);
    final platform = ref.watch(shortcutPlatformProvider);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );
    Widget note(String text) => Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space3,
        vertical: theme.space.space2,
      ),
      child: Text(text, style: caption),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.linksTitle,
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
                  Text(
                    l10n.linksTitle,
                    style: theme.typography.panelTitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  Text(format.integer(links.length), style: caption),
                  const Spacer(),
                  IconButton(
                    icon: IconName.plus,
                    label: l10n.editBarLink,
                    size: IconButtonSize.xs,
                    shortcut: ShellCommand.addLink.caps(platform),
                    disabledReason:
                        refusal?.call(l10n) ?? l10n.linksSelectTextFirst,
                    onPressed: refusal == null && selection != null
                        ? ref.read(linkToolProvider.notifier).addSelection
                        : null,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsetsDirectional.all(theme.space.space1_5),
                itemCount: links.length,
                itemBuilder: (context, index) => _LinkRow(
                  link: links[index],
                  selected: links[index].handle == selected,
                ),
              ),
            ),
            if (list != null && links.isEmpty) note(l10n.linksEmpty),
            if (list?.truncated ?? false) note(l10n.linksTruncated),
            note(l10n.linksNote),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width, defaultValue: null));
  }
}

/// One row: its kind's icon, where it goes, and its kind and page.
class _LinkRow extends ConsumerWidget {
  const new({required this.link, required this.selected});

  final LinkInfo link;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(openDocumentProvider);
    String number(int page) => bidiIsolate(format.integer(page));
    final pages = document?.pages.length ?? 0;
    final at = (document?.pageIndexOf(link.page) ?? 0) + 1;
    final broken = link.kind == LinkKind.broken;
    final kind = switch (link.kind) {
      LinkKind.web => l10n.linksKindWeb,
      LinkKind.mail => l10n.linksKindMail,
      LinkKind.page => l10n.linksKindPage,
      LinkKind.broken => '',
      LinkKind.script => l10n.linksKindScript,
      LinkKind.launch => l10n.linksKindLaunch,
      LinkKind.file => l10n.linksKindFile,
      LinkKind.address => l10n.linksKindAddress,
      LinkKind.action => l10n.linksKindAction,
      LinkKind.nothing => l10n.linksKindNothing,
    };
    final target = switch (link.kind) {
      LinkKind.page => l10n.linksPage(
        number((document?.pageIndexOf(link.targetPage ?? -1) ?? -1) + 1),
      ),
      LinkKind.broken => switch (link.wantedPage) {
        final wanted? => l10n.linksPage(number(wanted)),
        null => l10n.linksPageMissing,
      },
      LinkKind.mail => bidiIsolate(mailAddressOf(link.target)),
      _ when link.target.isEmpty => kind,
      _ => bidiIsolate(link.target),
    };
    final meta = broken
        ? l10n.linksBrokenMeta(pages, number(pages))
        : selected
        ? l10n.linksMetaEditing(kind, number(at))
        : l10n.linksMeta(kind, number(at));
    return FermanInteractive(
      onPressed: () => ref.read(linkToolProvider.notifier).select(link),
      selected: selected,
      selectable: true,
      semanticLabel: '$target, $meta',
      builder: (context, states, _) => Container(
        padding: EdgeInsetsDirectional.all(theme.space.space2),
        decoration: BoxDecoration(
          color: selected ? colors.surfaceSelected : null,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusSm),
          ),
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space2_5,
            children: [
              Icon(
                switch (link.kind) {
                  LinkKind.web => IconName.globe,
                  LinkKind.mail => IconName.mail,
                  LinkKind.page => IconName.fileText,
                  LinkKind.file => IconName.paperclip,
                  LinkKind.broken => IconName.triangleAlert,
                  LinkKind.nothing => IconName.link,
                  LinkKind.script ||
                  LinkKind.launch ||
                  LinkKind.address ||
                  LinkKind.action => IconName.shieldAlert,
                },
                size: theme.density.iconMd,
                color: broken
                    ? colors.warningSolid
                    : selected
                    ? colors.textAccent
                    : colors.iconSecondary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.space0_5,
                  children: [
                    Text(
                      target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      meta,
                      style: theme.typography.caption.copyWith(
                        color: broken
                            ? colors.warning
                            : selected
                            ? colors.textSecondary
                            : colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<LinkInfo>('link', link))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'));
  }
}
