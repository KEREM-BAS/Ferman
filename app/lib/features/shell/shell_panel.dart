import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/document_properties.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/not_editable.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
// The widgets library has its own Banner (the debug ribbon).
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The right panel (building block `FmDocPanel.dc.html`): `--panel-w` wide
/// on the panel surface with a subtle line on its start side, and a 40 px
/// heading with the panel's title and a "More" button.
///
/// The title is "Document" (FmDocPanel `kind="view"`), or "Edit" in Edit
/// mode (`kind="edit"`). With a document open the body holds its sections
/// ([DocumentPanelSections]): File, Fonts in this document and Security,
/// and in Edit mode only the fonts (its edit summary comes with editing,
/// M3). In Edit mode, text the pointer found that cannot be edited puts
/// a3-19's callout above them: "This text can't be edited" with the
/// reason, and on a scan a3-11's Recognize text, disabled until P3 (B025,
/// G39). While a block is edited, the heading carries its "Edited" badge
/// and [EditCallouts] come first: a3-4's overflow choices and a3-9's
/// "Totals don't update". More's menu is not drawn, so More stays disabled
/// with the future-version tooltip (B068). The mode panels of later milestones
/// (FmEditPanel, FmComments, FmFormPanel) take its place.
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
                (s.active != null &&
                    (s.preview?.dependents.isNotEmpty ?? false)),
          ),
        );
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
                  const Spacer(),
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
