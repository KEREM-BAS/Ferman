import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The canvas of a tab whose file did not open: a1-9c's drop zone error
/// for a file that is not a PDF, a1-9b's page for every other reason, with
/// the cause, Open another file…, Show in Finder (B119), the technical
/// details and "Copy technical details". The mode bar, the sidebar and the
/// status bar are hidden, as the boards draw them.
class OpenErrorTab extends ConsumerWidget {
  /// The error tab of [document].
  const new(this.document, {super.key});

  /// The tab, with its [ShellDocument.error].
  final ShellDocument document;

  /// a1-9b's column (`width: 560px`).
  static const double width = 560;

  /// a1-9b's gap (`gap: 14px`).
  static const double gap = 14;

  /// a1-9b's icon tile (`56px`) …
  static const double tileSize = 56;

  /// … and its icon (`size={28}`).
  static const double iconSize = 28;

  /// a1-9b's title size (`font-size: 20px`).
  static const double titleSize = 20;

  /// a1-9c's drop zone width (`width: 720px`) …
  static const double notPdfWidth = 720;

  /// … and its height (`min-height: 380px`).
  static const double notPdfHeight = 380;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final error = document.error!;
    final name = bidiIsolate(document.name);
    final opener = ref.read(documentOpenerProvider.notifier);
    final buttons = [
      Button(
        variant: ButtonVariant.primary,
        icon: IconName.folderOpen,
        onPressed: () =>
            unawaited(opener.pick(filterLabel: l10n.openPdfFilter)),
        child: Text(l10n.openAnotherFile),
      ),
      Button(
        disabled: true,
        disabledReason: Feature.showInFolder.disabledReason(context),
        child: Text(switch (ref.watch(shortcutPlatformProvider)) {
          ShortcutPlatform.mac => l10n.openShowInFinder,
          ShortcutPlatform.windows => l10n.openShowInExplorer,
          ShortcutPlatform.linux => l10n.openShowInFolder,
        }),
      ),
    ];
    if (error.messageKey == 'errorNotPdf') {
      return Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: notPdfWidth,
            child: DropZone(
              state: DropZoneState.error,
              minHeight: notPdfHeight,
              errorTitle: l10n.openNotPdfTitle,
              errorSubtitle: l10n.errorNotPdf(name),
              actions: [
                ...buttons,
                Button(
                  icon: IconName.refreshCw,
                  disabled: true,
                  disabledReason: Feature.createPdf.disabledReason(context),
                  child: Text(l10n.openConvertToPdf),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(theme.space.space6),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: [
              Container(
                width: tileSize,
                height: tileSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.dangerBg,
                  border: Border.all(
                    color: colors.dangerBorder,
                    width: theme.border.borderWidth,
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusLg),
                  ),
                ),
                child: Icon(
                  IconName.fileX,
                  size: iconSize,
                  color: colors.danger,
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  l10n.openFailedTitle(name),
                  textAlign: TextAlign.center,
                  style: theme.typography.dialogTitle.copyWith(
                    fontSize: titleSize,
                  ),
                ),
              ),
              Text(
                engineMessage(l10n, error, name),
                textAlign: TextAlign.center,
                style: theme.typography.prose.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(top: theme.space.space1_5),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: theme.space.space2,
                  runSpacing: theme.space.space2,
                  children: buttons,
                ),
              ),
              if (error.details case final details?)
                Container(
                  width: double.infinity,
                  margin: EdgeInsetsDirectional.only(top: theme.space.space2_5),
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: theme.space.space3,
                    vertical: theme.space.space2_5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    border: Border.all(
                      color: colors.borderSubtle,
                      width: theme.border.borderWidth,
                    ),
                    borderRadius: BorderRadius.all(
                      Radius.circular(theme.radius.radiusMd),
                    ),
                  ),
                  // Technical details are English and left to right in every
                  // UI language (G63).
                  child: Text(
                    details,
                    textDirection: TextDirection.ltr,
                    style: theme.typography.mono.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              OnboardingLink(
                label: l10n.startCopyTechnicalDetails,
                style: theme.typography.caption,
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: OpenProblem(
                      name: document.name,
                      error: error,
                    ).technicalDetails,
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

/// The canvas of a locked tab: a1-8's unlock dialog on the empty canvas.
/// It blocks only this tab (the board's "document-modal"): other tabs and
/// the start screen stay usable. Open tries the password; a wrong one shows
/// a1-8b's error under the field and keeps the attempt selected, so typing
/// replaces it; there is no lockout. Cancel closes the tab. The password
/// is passed to the engine and not kept (Q22: PDFium's copy).
class UnlockTab extends ConsumerStatefulWidget {
  /// The locked tab of [document].
  const new(this.document, {super.key});

  /// The locked tab.
  final ShellDocument document;

  @override
  ConsumerState<UnlockTab> createState() => _UnlockTabState();
}

class _UnlockTabState extends ConsumerState<UnlockTab> {
  final TextEditingController _password = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'Password');
  bool _show = false;
  bool _wrong = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The canvas around the dialog asks for focus too, and the first
    // request in a scope wins: the field takes it once the tab shows (a1-8).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _field.requestFocus();
    });
  }

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    _field.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final path = widget.document.path;
    if (_busy || path == null || _password.text.isEmpty) return;
    setState(() => _busy = true);
    final opened = await ref
        .read(documentOpenerProvider.notifier)
        .unlock(path, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _wrong = !opened;
    });
    if (!opened) {
      _password.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _password.text.length,
      );
      _field.requestFocus();
    }
  }

  void _cancel() {
    if (widget.document.path case final path?) {
      ref.read(documentOpenerProvider.notifier).close(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(theme.space.space6),
        child: Dialog(
          inline: true,
          icon: IconName.lock,
          title: l10n.errorPasswordRequired,
          description: l10n.unlockDescription(
            bidiIsolate(widget.document.name),
          ),
          cancelAction: Button(
            onPressed: _cancel,
            child: Text(l10n.unlockCancel),
          ),
          actions: [
            Button(
              variant: ButtonVariant.primary,
              onPressed: _busy ? null : () => unawaited(_open()),
              child: Text(l10n.unlockOpen),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space2_5,
            children: [
              TextField(
                label: l10n.unlockPassword,
                controller: _password,
                focusNode: _field,
                autofocus: true,
                obscureText: !_show,
                keyboardType: TextInputType.visiblePassword,
                error: _wrong ? l10n.errorWrongPassword : null,
                onChanged: (_) {
                  if (_wrong) setState(() => _wrong = false);
                },
                onSubmitted: (_) => unawaited(_open()),
              ),
              Checkbox(
                checked: _show,
                label: l10n.unlockShowPassword,
                onChanged: (value) => setState(() => _show = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
