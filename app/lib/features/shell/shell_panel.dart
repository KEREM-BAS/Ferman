import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The right panel (FmDocPanel): `--panel-w` wide on the panel surface with
/// a subtle line on its start side, and a 40 px heading with the panel's
/// title and a "More" button.
///
/// The title is "Document" (FmDocPanel `kind="view"`), or "Edit" in Edit
/// mode (`kind="edit"`). The panel's sections (file properties, fonts,
/// security) need an open document (M2), so the body is empty and More is
/// disabled with the future-version tooltip. The mode panels of later
/// milestones (FmEditPanel, FmComments, FmFormPanel) take its place.
class ShellPanel extends ConsumerWidget {
  /// The right panel.
  const new({super.key});

  /// FmDocPanel's heading: `height: 40px`.
  static const double headingHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(shellModeProvider);
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
        width: theme.size.panelW,
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
                  IconButton(
                    icon: IconName.ellipsis,
                    label: l10n.shellMore,
                    size: IconButtonSize.xs,
                    disabledReason: futureVersionReason(context),
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
