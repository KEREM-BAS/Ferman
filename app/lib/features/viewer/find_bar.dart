import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The find bar over the canvas (a2-4a to a2-4d): the `SearchReplaceBar`,
/// and under it the search options, a long search's progress (a2-4c) or
/// what a search that found nothing searched (a2-4d), in that place.
///
/// The options group is drawn open with no opener, so it shows while the
/// bar is open and no other panel takes its place (G115). Only the page
/// text is searched in M2: regular expressions and the other places to look
/// are disabled for a future version (B113, B114).
class FindBar extends ConsumerWidget {
  /// The bar of `findProvider`.
  const new({super.key});

  /// The width of the bar and its panels (`.fm-search` `width: 440px`).
  static const double width = SearchReplaceBar.width;

  /// The panels' side padding (`padding: 12px 14px`).
  static const double sidePadding = 14;

  /// The Look in row's gap (`gap: 14px`).
  static const double lookInGap = 14;

  /// a2-4c's spinner (`size={14}`).
  static const double spinnerSize = 14;

  /// Pages a search reads before its progress shows: one that takes more
  /// than a moment (a2-4c), and the engine's first progress event.
  static const int slowSearch = 25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final find = ref.watch(findProvider);
    if (!find.open) return const SizedBox.shrink();
    final notifier = ref.read(findProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final theme = context.ferman;
    final options = find.options;
    final searched = find.searched;
    final Widget panel;
    if (searched != null && searched >= slowSearch) {
      panel = _Searching(searched: searched, pages: find.pages);
    } else if (find.done && find.hasQuery && find.matches.isEmpty) {
      panel = _NoResults(find: find);
    } else {
      panel = _Options(options: options);
    }
    final slow = searched != null && searched >= slowSearch;
    // ⌥↵ shows every result in the sidebar's Search results tab (a2-4b).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, alt: true): () {
          ref.read(shellSidebarTabProvider.notifier).select(SidebarTab.search);
          ref.read(shellSidebarOpenProvider.notifier).open();
        },
      },
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: theme.space.space1_5,
          children: [
            SearchReplaceBar(
              key: ValueKey(find.focusRequests),
              labels: SearchReplaceBarLabels(
                region: l10n.findRegion,
                find: l10n.findField,
                replaceWith: l10n.findReplaceWith,
                matchCase: l10n.findMatchCase,
                wholeWord: l10n.findWholeWords,
                regex: l10n.findRegex,
                showReplace: l10n.findShowReplace,
                hideReplace: l10n.findHideReplace,
                previous: l10n.findPrevious,
                next: l10n.findNext,
                close: l10n.windowClose,
                replace: l10n.shellToolReplace,
                replaceAll: l10n.findReplaceAll,
                noResults: l10n.findNoResults,
                count: (current, total) => l10n.findCount(
                  format.integer(current),
                  format.integer(total),
                ),
              ),
              query: find.query,
              current: find.matches.isEmpty ? 0 : find.current + 1,
              total: find.matches.length,
              matchCase: options.matchCase,
              wholeWord: options.wholeWords,
              autofocus: true,
              replaceDisabledReason: Feature.findAndReplace.disabledReason(
                context,
              ),
              regexDisabledReason: Feature.searchRegex.disabledReason(context),
              onQueryChanged: notifier.setQuery,
              onToggleOption: (option, value) => switch (option) {
                SearchOption.matchCase => notifier.setOptions(
                  _with(options, matchCase: value),
                ),
                SearchOption.wholeWord => notifier.setOptions(
                  _with(options, wholeWords: value),
                ),
                SearchOption.regex => null,
              },
              onPrevious: notifier.previous,
              onNext: notifier.next,
              // Esc stops a long search first (a2-4c), then closes the bar.
              onClose: slow ? notifier.cancel : notifier.close,
            ),
            panel,
          ],
        ),
      ),
    );
  }
}

SearchOptions _with(
  SearchOptions options, {
  bool? matchCase,
  bool? wholeWords,
  bool? ignoreAccents,
}) => SearchOptions(
  matchCase: matchCase ?? options.matchCase,
  wholeWords: wholeWords ?? options.wholeWords,
  ignoreAccents: ignoreAccents ?? options.ignoreAccents,
);

/// The raised box the panels under the bar share.
class _Panel extends StatelessWidget {
  const new({required this.children, this.status = false, this.name});

  final List<Widget> children;

  /// Whether it is a status (a2-4c, a2-4d) rather than a group.
  final bool status;

  /// The group's accessible name.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Semantics(
      container: true,
      liveRegion: status,
      label: name,
      child: Container(
        width: FindBar.width,
        padding: EdgeInsetsDirectional.symmetric(
          vertical: theme.space.space3,
          horizontal: FindBar.sidePadding,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusLg),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space2_5,
          children: children,
        ),
      ),
    );
  }
}

/// The search options (a2-4a): Match and Look in.
class _Options extends ConsumerWidget {
  const new({required this.options});

  final SearchOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(findProvider.notifier);
    final casing = LocaleCasing.of(context);
    Widget heading(String text) => Semantics(
      header: true,
      child: Text(
        casing.upper(text),
        style: theme.typography.label.copyWith(
          color: theme.colors.textTertiary,
        ),
      ),
    );
    final later = Feature.searchScopes.disabledReason(context);
    Widget check(
      String label, {
      required String reason,
      bool checked = false,
    }) => Checkbox(
      checked: checked,
      label: label,
      disabled: true,
      disabledReason: reason,
    );
    return _Panel(
      name: l10n.findOptions,
      children: [
        heading(l10n.findMatch),
        // `grid-template-columns: 1fr 1fr; gap: 8px`.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space2,
          children: [
            Row(
              spacing: theme.space.space2,
              children: [
                Expanded(
                  child: Checkbox(
                    checked: options.matchCase,
                    label: l10n.findMatchCase,
                    onChanged: (value) =>
                        notifier.setOptions(_with(options, matchCase: value)),
                  ),
                ),
                Expanded(
                  child: Checkbox(
                    checked: options.wholeWords,
                    label: l10n.findWholeWords,
                    onChanged: (value) =>
                        notifier.setOptions(_with(options, wholeWords: value)),
                  ),
                ),
              ],
            ),
            Row(
              spacing: theme.space.space2,
              children: [
                Expanded(
                  child: check(
                    l10n.findRegex,
                    reason: Feature.searchRegex.disabledReason(context),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
        Checkbox(
          checked: options.ignoreAccents,
          label: l10n.findIgnoreAccents,
          description: l10n.findIgnoreAccentsBody,
          onChanged: (value) =>
              notifier.setOptions(_with(options, ignoreAccents: value)),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(top: theme.space.space1),
          child: heading(l10n.findLookIn),
        ),
        Wrap(
          spacing: FindBar.lookInGap,
          runSpacing: theme.space.space2,
          children: [
            // The page text is always searched in M2 (B114).
            check(l10n.findPageText, checked: true, reason: later),
            check(l10n.findComments, reason: later),
            check(l10n.findFormFields, reason: later),
            check(l10n.findBookmarks, reason: later),
          ],
        ),
      ],
    );
  }
}

/// A long search's progress (a2-4c).
class _Searching extends ConsumerWidget {
  const new({required this.searched, required this.pages});

  final int searched;
  final int pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final text = l10n.findSearching(
      format.integer(searched),
      format.integer(pages),
    );
    return _Panel(
      status: true,
      children: [
        Row(
          spacing: theme.space.space2_5,
          children: [
            const Spinner(size: FindBar.spinnerSize),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.space.space0_5,
                children: [
                  Text(
                    text,
                    style: theme.typography.bodyStrong.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    l10n.findSearchingBody,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Button(
              size: ButtonSize.sm,
              variant: ButtonVariant.ghost,
              onPressed: ref.read(findProvider.notifier).cancel,
              child: Text(l10n.findCancel),
            ),
          ],
        ),
        ProgressBar(
          value: pages == 0 ? 0 : searched / pages,
          size: ProgressSize.md,
          label: text,
        ),
      ],
    );
  }
}

/// What a search that found nothing searched (a2-4d).
class _NoResults extends ConsumerWidget {
  const new({required this.find});

  final FindState find;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    return _Panel(
      status: true,
      children: [
        Text(
          l10n.findNoneTitle(find.query.trim()),
          style: theme.typography.bodyStrong,
        ),
        Text(
          (find.options.ignoreAccents
              ? l10n.findNoneBody
              : l10n.findNoneBodyExact)(find.pages, format.integer(find.pages)),
          style: theme.typography.caption.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Button(
            size: ButtonSize.sm,
            icon: IconName.search,
            disabled: true,
            disabledReason: Feature.searchScopes.disabledReason(context),
            child: Text(l10n.findNoneAction),
          ),
        ),
      ],
    );
  }
}
