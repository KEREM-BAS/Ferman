import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/default_app.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'default_app_prompt.g.dart';

/// Whether a1-3 was answered in this run, so the start screen does not ask
/// again when it shows again.
@Riverpod(keepAlive: true)
class DefaultAppAsked extends _$DefaultAppAsked {
  @override
  bool build() => false;

  /// Records the answer.
  void answer() => state = true;
}

/// a1-3: the start screen asks once a run, after onboarding, whether
/// Ferman should open PDF files, while another app does and the person
/// has not turned it down for good (`AppSettings.askDefaultApp`, B080).
/// Only macOS says which app that is, so only macOS asks (B101, B102).
///
/// Use Ferman for PDFs asks macOS, which asks the person; Not now closes
/// it, and with Don't ask again it never asks again (G123). Settings ›
/// General keeps the button either way.
class DefaultAppPrompt extends ConsumerStatefulWidget {
  /// The question, when it is due.
  const new({super.key});

  @override
  ConsumerState<DefaultAppPrompt> createState() => _DefaultAppPromptState();
}

class _DefaultAppPromptState extends ConsumerState<DefaultAppPrompt> {
  bool _dontAsk = false;

  @override
  Widget build(BuildContext context) {
    final ask = ref.watch(
      settingsProvider.select((settings) => settings.askDefaultApp),
    );
    final handler = ref.watch(pdfHandlerProvider).value;
    if (!ask ||
        ref.watch(defaultAppAskedProvider) ||
        handler == null ||
        handler.ferman) {
      return const SizedBox.shrink();
    }
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final parts = [
      Text(
        l10n.defaultAppNow,
        style: theme.typography.body.copyWith(
          color: theme.colors.textSecondary,
        ),
      ),
      Text(
        bidiIsolate(handler.name),
        style: theme.typography.body.copyWith(
          fontWeight: theme.typeScale.weightMedium,
        ),
      ),
      Icon(
        IconName.arrowRight,
        size: theme.density.iconMd,
        color: theme.colors.iconSecondary,
      ),
      Text(
        l10n.appName,
        style: theme.typography.body.copyWith(
          fontWeight: theme.typeScale.weightSemibold,
        ),
      ),
    ];

    void answer({required bool never}) {
      ref.read(defaultAppAskedProvider.notifier).answer();
      if (never) {
        unawaited(
          changeSetting(
            ref,
            (settings) => settings.copyWith(askDefaultApp: false),
          ),
        );
      }
    }

    return Dialog(
      icon: IconName.fileText,
      title: l10n.defaultAppTitle,
      description: l10n.defaultAppDescription,
      onClose: () => answer(never: _dontAsk),
      closeLabel: l10n.defaultAppNotNow,
      footerStart: Checkbox(
        checked: _dontAsk,
        label: l10n.defaultAppDontAsk,
        onChanged: (checked) => setState(() => _dontAsk = checked),
      ),
      actions: [
        Button(
          onPressed: () => answer(never: _dontAsk),
          child: Text(l10n.defaultAppNotNow),
        ),
        Button(
          variant: ButtonVariant.primary,
          onPressed: () {
            answer(never: true);
            unawaited(makeFermanDefault(ref));
          },
          child: Text(l10n.defaultAppUse),
        ),
      ],
      child: Container(
        padding: EdgeInsetsDirectional.all(theme.space.space3),
        decoration: BoxDecoration(
          color: theme.colors.surfaceSunken,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
        ),
        child: WindowMetrics.isPhone(context)
            // A long app name has no room on one line.
            ? Wrap(
                spacing: theme.space.space3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: parts,
              )
            : Row(spacing: theme.space.space3, children: parts),
      ),
    );
  }
}
