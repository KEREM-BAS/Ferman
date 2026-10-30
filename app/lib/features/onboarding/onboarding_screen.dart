import 'package:ferman/app/router.dart';
import 'package:ferman/features/onboarding/free_step.dart';
import 'package:ferman/features/onboarding/language_picker.dart';
import 'package:ferman/features/onboarding/privacy_step.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The steps of first run, in order.
enum OnboardingStep {
  /// The language picker (a1-1).
  language,

  /// Everything stays on your device (a1-2b).
  privacy,

  /// Free forever, nothing locked (a1-2c).
  free,
}

/// First run: the language picker (a1-1), then two welcome steps, the
/// privacy facts (a1-2b) and the free-forever step (a1-2c), under the bare
/// title bar.
///
/// The router shows it instead of the start screen while
/// `AppSettings.onboardingCompleted` is false. "Start using Ferman", Skip
/// and Esc on a welcome step finish first run: they set
/// `onboardingCompleted` and go to the start screen, which every later
/// launch opens directly.
///
/// The design's three welcome steps start with a1-2a ("Edit any PDF like a
/// document"), whose specimen is a live editing frame; it joins the flow
/// with the editor in M3, so M1 counts two steps ("1 of 2", "2 of 2").
///
/// The step is state, not a route: the link to Settings › Privacy pushes
/// the settings over this screen, and closing them comes back to the same
/// step.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// First run, starting at [initialStep].
  const new({super.key, this.initialStep = OnboardingStep.language});

  /// The step shown first.
  final OnboardingStep initialStep;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late OnboardingStep _step = widget.initialStep;
  bool _finishing = false;

  /// The screen's own focus node: focus rests here on the welcome steps,
  /// so Esc works there at once.
  final FocusNode _focus = FocusNode(debugLabel: 'OnboardingScreen');

  /// The welcome steps after the language picker.
  static const int _welcomeSteps = 2;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _show(OnboardingStep step) {
    setState(() => _step = step);
    // The picker's search field had focus; it leaves with the picker, so
    // focus comes back to the screen, where Esc is bound.
    if (step != OnboardingStep.language) _focus.requestFocus();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await ref
          .read(settingsProvider.notifier)
          .change((settings) => settings.copyWith(onboardingCompleted: true));
    } on SettingsStoreException {
      // Done for this session; first run shows again at the next launch.
    }
    // Files the system sent during first run (ADR 0021) show at once.
    if (mounted) {
      context.go(
        ref.read(shellDocumentsProvider).placeholder
            ? Routes.start
            : Routes.editor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget content;
    switch (_step) {
      case OnboardingStep.language:
        content = LanguagePicker(
          onContinue: () => _show(OnboardingStep.privacy),
        );
      case OnboardingStep.privacy:
        content = WelcomeStep(
          step: 1,
          count: _welcomeSteps,
          title: l10n.onboardingPrivacyTitle,
          paragraphs: [l10n.onboardingPrivacyBody],
          aside: PrivacyFacts(
            onOpenPrivacySettings: () =>
                context.push(Routes.settingsPane('privacy')),
          ),
          nextLabel: l10n.onboardingNext,
          onNext: () => _show(OnboardingStep.free),
          onBack: () => _show(OnboardingStep.language),
          onSkip: _finish,
        );
      case OnboardingStep.free:
        content = WelcomeStep(
          step: 2,
          count: _welcomeSteps,
          title: l10n.onboardingFreeTitle,
          paragraphs: [l10n.onboardingFreeBody],
          note: const LicenceNote(),
          aside: const FeatureGrid(),
          asideWidth: _freeAsideWidth,
          nextLabel: l10n.onboardingStartUsing,
          onNext: _finish,
          onBack: () => _show(OnboardingStep.privacy),
        );
    }
    return CallbackShortcuts(
      bindings: {
        if (_step != OnboardingStep.language)
          const SingleActivator(LogicalKeyboardKey.escape): _finish,
      },
      child: Focus(focusNode: _focus, autofocus: true, child: content),
    );
  }

  /// The end column of a1-2c (`minmax(0,540px)`).
  static const double _freeAsideWidth = 540;
}
