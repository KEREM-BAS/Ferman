import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/block_language.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_panel.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/shell/document_properties.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/not_editable.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
// The widgets library has its own Banner (the debug ribbon).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The right panel (building block `FmDocPanel.dc.html`): `--panel-w` wide
/// on the panel surface with a subtle line on its start side, and a 40 px
/// heading with the panel's title and a "More" button.
///
/// The title is "Document" (FmDocPanel `kind="view"`), or "Edit" in Edit
/// mode (`kind="edit"`). With a document open the body holds its sections
/// ([DocumentPanelSections]): File, Fonts in this document and Security,
/// and in Edit mode a3-1a's two tips (while no block is edited), its edit
/// summary (once there are edits) and the fonts. In Edit mode, text the
/// pointer found that cannot be edited puts
/// a3-19's callout above them: "This text can't be edited" with the
/// reason, and on a scan a3-11's Recognize text, disabled until P3 (B025,
/// G39). While a block is edited, the heading carries its "Edited" badge
/// and [EditCallouts] come first: a3-4's overflow choices and a3-9's
/// "Totals don't update". More's menu is not drawn, so More stays disabled
/// with the future-version tooltip (B068). While a block is edited,
/// [FmEditPanel] takes its place, with its Language section
/// ([BlockLanguageSection], a3-14); the mode panels of later milestones
/// (FmComments, FmFormPanel) will too.
class FmDocPanel extends ConsumerWidget {
  /// The right panel.
  const new({super.key, this.width});

  /// The right panel's width; null takes its FmWindow width. The shell passes
  /// the width the user dragged it to (B094).
  final double? width;

  /// FmDocPanel's heading: `height: 40px`.
  static const double headingHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(shellModeProvider);
    final document = ref.watch(shellDocumentsProvider).active;
    final edit = mode == FermanMode.edit;
    final style = edit
        ? ref.watch(documentEditorProvider.select((s) => s.style))
        : null;
    if (style != null) return FmEditPanel(info: style, width: width);
    final callout = edit ? ref.watch(editCalloutProvider) : null;
    final edited =
        edit &&
        ref.watch(
          documentEditorProvider.select(
            (s) => s.active != null && s.preview != null,
          ),
        );
    final editCallouts =
        edit &&
        ref.watch(
          documentEditorProvider.select(
            (s) =>
                s.asking != null ||
                s.glyphs != null ||
                s.notice != null ||
                s.markedChars.isNotEmpty ||
                (s.active != null &&
                    (s.preview?.dependents.isNotEmpty ?? false)),
          ),
        );
    final language =
        edit &&
        ref.watch(documentEditorProvider.select((s) => s.active != null));
    final title = mode == FermanMode.edit
        ? l10n.shellModeEdit
        : l10n.shellPanelDocument;
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
              height: headingHeight,
              padding: EdgeInsetsDirectional.only(
                start: theme.space.space3,
                end: theme.space.space1_5,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  Expanded(
                    child: Row(
                      spacing: theme.space.space2,
                      children: [
                        Flexible(
                          child: ExcludeSemantics(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.panelTitle.copyWith(
                                color: theme.colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (edited)
                          Badge(
                            label: l10n.editBadgeEdited,
                            tone: BadgeTone.edited,
                            dot: true,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: IconName.ellipsis,
                    label: l10n.shellMore,
                    size: IconButtonSize.xs,
                    disabledReason: Feature.rightPanelSections.disabledReason(
                      context,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  document?.document == null && callout == null && !editCallouts
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (editCallouts) const EditCallouts(),
                          if (callout != null)
                            Padding(
                              padding: EdgeInsetsDirectional.all(
                                theme.space.space3,
                              ),
                              child: Banner(
                                tone: BannerTone.neutral,
                                title: l10n.editNotEditableTitle,
                                actions: [
                                  if (callout == NotEditableReason.imageOnly)
                                    Button(
                                      size: ButtonSize.sm,
                                      disabledReason: Feature.ocr
                                          .disabledReason(context),
                                      child: Text(l10n.shellToolRecognizeText),
                                    ),
                                ],
                                child: Text(notEditableBody(l10n, callout)),
                              ),
                            ),
                          if (language) const BlockLanguageSection(),
                          if (edit && document?.document != null)
                            _EditSummary(edits: document!.editCount),
                          if (document?.document != null)
                            DocumentPanelSections(
                              tab: document!,
                              edit: mode == FermanMode.edit,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FmDocPanel `kind="edit"` above the fonts (a3-1a): the two tips, gone while
/// a block is edited, and the number of edits with Review.
class _EditSummary extends ConsumerWidget {
  const new({required this.edits});

  /// The edits that apply.
  final int edits;

  /// Stands for the key cap in the second tip's sentence.
  static const String _keyMark = '\ufffc';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final altKey = switch (ref.watch(shortcutPlatformProvider)) {
      ShortcutPlatform.mac => '\u2325',
      ShortcutPlatform.windows || ShortcutPlatform.linux => 'Alt',
    };
    final editing = ref.watch(
      documentEditorProvider.select((s) => s.active != null),
    );
    final padding = EdgeInsetsDirectional.all(theme.space.space3);
    final line = BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: theme.colors.borderSubtle,
          width: theme.border.borderWidth,
        ),
      ),
    );
    final body = theme.typography.body.copyWith(
      color: theme.colors.textPrimary,
    );
    Widget tip(IconName icon, Widget text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2_5,
      children: [
        Icon(
          icon,
          size: theme.density.iconMd,
          color: theme.colors.iconSecondary,
        ),
        Expanded(child: text),
      ],
    );
    final keys = l10n.editPanelTipKeys(_keyMark).split(_keyMark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!editing)
          Container(
            padding: padding,
            decoration: line,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space2_5,
              children: [
                tip(
                  IconName.mousePointer2,
                  Text(l10n.editPanelTipClick, style: body),
                ),
                tip(
                  IconName.keyboard,
                  Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        for (var i = 0; i < keys.length; i++) ...[
                          if (i > 0)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Kbd([altKey]),
                            ),
                          TextSpan(text: keys[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (edits > 0)
          Container(
            padding: padding,
            decoration: line,
            child: Row(
              spacing: theme.space.space2,
              children: [
                Badge(
                  label: l10n.closingEdits(edits, format.integer(edits)),
                  tone: BadgeTone.edited,
                  dot: true,
                ),
                Expanded(
                  child: Text(
                    l10n.editPanelInSession,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ),
                Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.sm,
                  onPressed: () => showReviewList(ref),
                  child: Text(l10n.editPanelReview),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('edits', edits));
  }
}
