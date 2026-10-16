import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The first-run language picker, board a1-1 (`01 First run and
/// files.dc.html`).
///
/// A raised card in the middle of the window: the wordmark, "Choose a
/// language", a line that says why the selected language is selected, a
/// search field, the 21 languages in two columns (each by its own name in
/// its own script and direction, its English name beside it) and a footer
/// with the translation link and Continue.
///
/// Choosing a language switches the interface at once, before Continue
/// (a1-1 note); Arabic, Persian and Hebrew mirror the whole UI. Languages
/// without a translation stay selectable and say "Not translated yet"
/// (G20); the UI then shows English. The operating system's language says
/// "System language", and choosing it stores no choice, so the app keeps
/// following the system.
///
/// Keyboard (a1-1 note): the search field has focus when the picker opens,
/// so typing filters at once and Enter continues with the language shown
/// as selected. Tab reaches the search field, the list and the footer; the
/// list is one Tab stop (a radio group, as `Radio` does it), on the
/// selected language or, when the filter hides it, the first match. ↑ and
/// ↓ move through the list in its order and wrap; Space selects; Enter
/// selects the focused language and continues. Typing in the search field
/// filters by the own name, the English name or the language tag, in any
/// script. A click selects without moving focus or showing the focus ring
/// (G22), as `FermanInteractive` does.
class LanguagePicker extends ConsumerStatefulWidget {
  /// The picker; [onContinue] leaves it for the welcome steps.
  const new({required this.onContinue, super.key});

  /// Called by Continue and by Enter.
  final VoidCallback onContinue;

  /// The card's width (`width: 760px`).
  static const double cardWidth = 760;

  /// The card's padding (`padding: 36px 40px 28px`): top …
  static const double cardPaddingTop = 36;

  /// … sides …
  static const double cardPaddingX = 40;

  /// … and bottom.
  static const double cardPaddingBottom = 28;

  /// The wordmark's size (`font-size: 24px` on `--type-wordmark`).
  static const double wordmarkSize = 24;

  /// The rows per column (`grid-template-rows: repeat(11, auto)`).
  static const int rowsPerColumn = 11;

  /// A row's height (`height: 36px`).
  static const double rowHeight = 36;

  /// The gap between the two columns (`gap: 2px 12px`).
  static const double columnGap = 12;

  @override
  ConsumerState<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends ConsumerState<LanguagePicker> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _search = FocusNode(debugLabel: 'language search');
  final Map<AppLanguage, FocusNode> _nodes = {
    for (final language in AppLanguage.values)
      language: FocusNode(debugLabel: 'language ${language.tag}'),
  };

  /// The row the list's one Tab stop is on, once focus or a choice moved
  /// it; null takes the selected language (or the first match).
  AppLanguage? _stop;

  @override
  void initState() {
    super.initState();
    // The onboarding screen's wrapper takes autofocus first (it stays the
    // Esc fallback of the welcome steps), so focus moves here once that has
    // settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _search.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// The languages that match the search, in the picker's order.
  List<AppLanguage> get _visible {
    final query = LocaleCasing.root.lower(_query.text.trim());
    if (query.isEmpty) return AppLanguage.values;
    bool matches(String text) => LocaleCasing.root.lower(text).contains(query);
    return [
      for (final language in AppLanguage.values)
        if (matches(language.endonym) ||
            matches(language.englishName) ||
            matches(language.tag))
          language,
    ];
  }

  Future<void> _select(AppLanguage language) async {
    if (_stop != language) setState(() => _stop = language);
    // The system's own language stores no choice: the app keeps following
    // the system.
    final system = ref.read(systemLanguageProvider);
    try {
      await ref
          .read(settingsProvider.notifier)
          .change(
            (settings) => settings.copyWith(
              languageCode: () => language == system ? null : language.tag,
            ),
          );
    } on SettingsStoreException {
      // Kept for this session; the language still switches.
    }
  }

  void _move(List<AppLanguage> visible, AppLanguage from, int step) {
    final index = visible.indexOf(from);
    if (index < 0 || visible.isEmpty) return;
    final next = visible[(index + step) % visible.length];
    _nodes[next]?.requestFocus();
    setState(() => _stop = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(appLanguageProvider);
    final system = ref.watch(systemLanguageProvider);
    final visible = _visible;
    final stop = switch (_stop) {
      final moved? when visible.contains(moved) => moved,
      _ when visible.contains(selected) => selected,
      _ => visible.firstOrNull,
    };

    Widget row(AppLanguage language) => _LanguageRow(
      language: language,
      selected: language == selected,
      isSystem: language == system,
      focusNode: _nodes[language]!..skipTraversal = language != stop,
      onSelect: () => unawaited(_select(language)),
      onContinue: () {
        // The choice applies at once; storing it finishes in the background.
        unawaited(_select(language));
        widget.onContinue();
      },
      onMove: (step) => _move(visible, language, step),
    );

    final columns = [
      visible.take(LanguagePicker.rowsPerColumn).toList(),
      visible.skip(LanguagePicker.rowsPerColumn).toList(),
    ];
    final listHeight =
        LanguagePicker.rowsPerColumn * LanguagePicker.rowHeight +
        (LanguagePicker.rowsPerColumn - 1) * theme.space.space0_5;
    final list = SizedBox(
      height: listHeight,
      child: visible.isEmpty
          ? Center(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.onboardingLanguageNoMatch(_query.text.trim()),
                  style: typography.body.copyWith(color: colors.textSecondary),
                ),
              ),
            )
          : Semantics(
              container: true,
              explicitChildNodes: true,
              role: SemanticsRole.radioGroup,
              label: l10n.languageAppLanguage,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: LanguagePicker.columnGap,
                children: [
                  for (final column in columns)
                    Expanded(
                      child: Column(
                        spacing: theme.space.space0_5,
                        children: [
                          for (final language in column) row(language),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );

    final subtitle = system != null && selected == system
        ? l10n.onboardingLanguageSubtitleSystem(selected.endonym)
        : l10n.onboardingLanguageSubtitle;
    final caption = typography.caption.copyWith(color: colors.textSecondary);

    final card = Container(
      constraints: const BoxConstraints(maxWidth: LanguagePicker.cardWidth),
      padding: const EdgeInsetsDirectional.fromSTEB(
        LanguagePicker.cardPaddingX,
        LanguagePicker.cardPaddingTop,
        LanguagePicker.cardPaddingX,
        LanguagePicker.cardPaddingBottom,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusXl)),
        boxShadow: theme.elevation.shadowDialog,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space5,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space2,
            children: [
              ExcludeSemantics(
                child: Text(
                  l10n.appName,
                  style: typography.wordmark.copyWith(
                    fontSize: LanguagePicker.wordmarkSize,
                  ),
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  l10n.onboardingLanguageTitle,
                  style: typography.headline,
                ),
              ),
              Text(
                subtitle,
                style: typography.prose.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          TextField(
            controller: _query,
            focusNode: _search,
            icon: IconName.search,
            placeholder: l10n.onboardingLanguageSearchPlaceholder,
            semanticLabel: l10n.onboardingLanguageSearchLabel,
            // A new filter moves the Tab stop back to the selected
            // language, or the first match.
            onChanged: (_) => setState(() => _stop = null),
            onSubmitted: (_) => widget.onContinue(),
          ),
          FocusTraversalGroup(child: list),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.borderSubtle,
                  width: theme.border.borderWidth,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.only(top: theme.space.space2),
              child: Row(
                spacing: theme.space.space3,
                children: [
                  Icon(IconName.languages, color: colors.iconSecondary),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: theme.space.space1,
                      children: [
                        Text(l10n.onboardingLanguageMissing, style: caption),
                        OnboardingLink(
                          label: l10n.onboardingLanguageHelpTranslate,
                          style: caption,
                          disabledReason: futureVersionReason(context),
                        ),
                      ],
                    ),
                  ),
                  Button(
                    variant: ButtonVariant.primary,
                    size: ButtonSize.lg,
                    onPressed: widget.onContinue,
                    child: Text(l10n.onboardingContinue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(theme.space.space6),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of the language list: a radio named by the language's own name,
/// with the English name (or "System language") at the end and "Not
/// translated yet" under it for a language without a translation.
class _LanguageRow extends StatefulWidget {
  const new({
    required this.language,
    required this.selected,
    required this.isSystem,
    required this.focusNode,
    required this.onSelect,
    required this.onContinue,
    required this.onMove,
  });

  final AppLanguage language;
  final bool selected;
  final bool isSystem;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final VoidCallback onContinue;
  final ValueChanged<int> onMove;

  @override
  State<_LanguageRow> createState() => _LanguageRowState();
}

class _ContinueIntent extends Intent {
  const new();
}

class _MoveIntent extends Intent {
  const new(this.step);

  final int step;
}

class _LanguageRowState extends State<_LanguageRow> {
  bool _hovered = false;
  bool _focusVisible = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.enter): _ContinueIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): _ContinueIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
  };

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onSelect();
        return null;
      },
    ),
    _ContinueIntent: CallbackAction<_ContinueIntent>(
      onInvoke: (_) {
        widget.onContinue();
        return null;
      },
    ),
    _MoveIntent: CallbackAction<_MoveIntent>(
      onInvoke: (intent) {
        widget.onMove(intent.step);
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final language = widget.language;
    final english = Locale.fromSubtags(
      languageCode: AppLanguage.english.locale.languageCode,
    );
    final caption = typography.caption.copyWith(color: colors.textTertiary);
    final trailing = widget.isSystem
        ? l10n.languageSystem
        : language.englishName;
    final state = language.translated ? null : l10n.languageNotTranslated;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));

    final content = Container(
      height: LanguagePicker.rowHeight,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space2_5,
      ),
      decoration: BoxDecoration(
        color: widget.selected
            ? colors.surfaceSelected
            : _hovered
            ? colors.surfaceHover
            : null,
        borderRadius: radius,
      ),
      child: Row(
        spacing: theme.space.space2_5,
        children: [
          SizedBox(
            width: Icon.defaultSize,
            child: widget.selected
                ? Icon(
                    IconName.check,
                    color: colors.textAccent,
                    strokeWidth: _checkStroke,
                  )
                : null,
          ),
          Text(
            language.endonym,
            textDirection: language.textDirection,
            style: typography.prose.copyWith(
              fontWeight: theme.typeScale.weightMedium,
              color: widget.selected ? colors.textAccent : colors.textPrimary,
              locale: language.locale,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: widget.isSystem
                      ? caption
                      : caption.copyWith(locale: english),
                ),
                if (state != null)
                  Text(
                    state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      label: [language.endonym, trailing, ?state].join(', '),
      onTap: widget.onSelect,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        shortcuts: _shortcuts,
        actions: _actions,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
        child: GestureDetector(
          excludeFromSemantics: true,
          // A click selects; it neither moves focus nor shows the ring.
          onTap: widget.onSelect,
          child: FocusRing(
            visible: _focusVisible,
            style: FocusRingStyle.inset,
            borderRadius: radius,
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }

  /// The check's stroke (`stroke-width="2"`).
  static const double _checkStroke = 2;
}
