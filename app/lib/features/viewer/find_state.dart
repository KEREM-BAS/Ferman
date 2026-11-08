import 'dart:async';

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'find_state.g.dart';

/// The find bar's state (a2-4a to a2-4d): its query and options, the
/// matches found so far and the current one, and how far a running search
/// has read.
@immutable
final class FindState {
  /// The bar closed, nothing searched.
  const new({
    this.open = false,
    this.query = '',
    this.options = const SearchOptions(),
    this.matches = const [],
    this.current = 0,
    this.searched,
    this.pages = 0,
    this.done = false,
    this.textless = false,
    this.focusRequests = 0,
    this.stale = false,
  });

  /// Whether the bar shows.
  final bool open;

  /// What the field holds.
  final String query;

  /// How it matches.
  final SearchOptions options;

  /// The matches so far, in page order.
  final List<SearchMatch> matches;

  /// The current match's index in [matches].
  final int current;

  /// Pages read while a search runs, or null when none runs.
  final int? searched;

  /// Pages in the document.
  final int pages;

  /// Whether the last search read every page.
  final bool done;

  /// Whether the last search found no text on any page: a scan (a2-3m).
  final bool textless;

  /// How often ⌘F or Ctrl+F asked for the field's focus.
  final int focusRequests;

  /// Whether the document's pages changed while another was shown: the search
  /// runs again when it shows again.
  final bool stale;

  /// Whether a query is in the field.
  bool get hasQuery => query.trim().isNotEmpty;

  /// The current match, if any.
  SearchMatch? get currentMatch =>
      current < matches.length ? matches[current] : null;

  /// A copy with the given values.
  FindState copyWith({
    bool? open,
    String? query,
    SearchOptions? options,
    List<SearchMatch>? matches,
    int? current,
    int? Function()? searched,
    int? pages,
    bool? done,
    bool? textless,
    int? focusRequests,
    bool? stale,
  }) => FindState(
    open: open ?? this.open,
    query: query ?? this.query,
    options: options ?? this.options,
    matches: matches ?? this.matches,
    current: current ?? this.current,
    searched: searched == null ? this.searched : searched(),
    pages: pages ?? this.pages,
    done: done ?? this.done,
    textless: textless ?? this.textless,
    focusRequests: focusRequests ?? this.focusRequests,
    stale: stale ?? this.stale,
  );
}

/// Finds text in the open document, as `findProvider`. Each document keeps
/// its own search: switching tabs stops a running one, keeping what it
/// found, and switching back shows it again.
@Riverpod(keepAlive: true)
class Find extends _$Find {
  StreamSubscription<SearchUpdate>? _search;

  @override
  FindState build() {
    final document = ref.watch(openDocumentProvider);
    ref.onDispose(_stop);
    _stop();
    if (document == null) return const FindState();
    final memory = ref.read(documentMemoryProvider(document.id));
    listenSelf((_, next) => memory.remember(next));
    final recalled = memory.recall<FindState>();
    if (recalled?.stale ?? false) {
      // Providers do not change while they build.
      scheduleMicrotask(() {
        if (ref.mounted) _start();
      });
    }
    return recalled?.copyWith(searched: () => null, stale: false) ??
        const FindState();
  }

  /// The document's pages changed: what was found goes, and the search runs
  /// again.
  void pagesChanged() {
    if (state.hasQuery) _start();
  }

  /// The pages of [document], not the one shown, changed: what it found goes
  /// when it shows again.
  void pagesChangedElsewhere(int document) {
    final memory = ref.read(documentMemoryProvider(document));
    final kept = memory.recall<FindState>();
    if (kept != null && kept.hasQuery) {
      memory.remember(kept.copyWith(stale: true));
    }
  }

  /// Shows the bar and focuses its field (⌘F, Ctrl+F).
  void open() => state = state.copyWith(
    open: true,
    focusRequests: state.focusRequests + 1,
  );

  /// Hides the bar and drops the search (Esc).
  void close() {
    _stop();
    state = FindState(
      focusRequests: state.focusRequests,
      options: state.options,
    );
  }

  /// Searches for [query].
  // shortcut: every keystroke starts a new search; the engine keeps each
  // page's text, so only the first search reads content. Debounce if a
  // very long document makes typing slow.
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
    _start();
  }

  /// Searches again with [options].
  void setOptions(SearchOptions options) {
    if (options == state.options) return;
    state = state.copyWith(options: options);
    _start();
  }

  /// Goes to the next match (↵), after the last back to the first.
  void next() => _step(1);

  /// Goes to the previous match (⇧↵).
  void previous() => _step(-1);

  /// Makes the match at [index] current and shows its page (the sidebar's
  /// results).
  void select(int index) {
    if (index < 0 || index >= state.matches.length) return;
    state = state.copyWith(current: index);
    _show();
  }

  /// Stops the running search, keeping what it found (a2-4c's Cancel).
  void cancel() {
    _stop();
    state = state.copyWith(searched: () => null);
  }

  void _step(int by) {
    final count = state.matches.length;
    if (count == 0) return;
    select((state.current + by) % count);
  }

  void _show() {
    final match = state.currentMatch;
    if (match == null) return;
    ref.read(viewerProvider.notifier).goToPage(match.page);
    if (match.comment case final handle?) {
      ref.read(commentSelectionProvider.notifier).select(handle);
    }
  }

  void _stop() {
    unawaited(_search?.cancel());
    _search = null;
  }

  void _start() {
    _stop();
    final document = ref.read(openDocumentProvider);
    state = state.copyWith(
      matches: const [],
      current: 0,
      searched: () => null,
      pages: document?.pages.length ?? 0,
      done: false,
      textless: false,
    );
    if (document == null || !state.hasQuery) return;
    state = state.copyWith(searched: () => 0);
    late final StreamSubscription<SearchUpdate> search;
    // Reading `state` first runs a rebuild that a tab switch left pending,
    // which stops this search: its late events must not reach the other
    // document.
    bool stale() => !identical(_search, search);
    search = _search = ref
        .read(engineServiceProvider)
        .search(document.id, state.query, state.options)
        .listen(
          (update) {
            final current = state;
            if (stale()) return;
            switch (update) {
              case SearchMatches(:final matches):
                state = current.copyWith(
                  matches: [...current.matches, ...matches],
                );
                if (current.matches.isEmpty) _show();
              case SearchProgress(:final searched, :final pages):
                state = current.copyWith(
                  searched: () => searched,
                  pages: pages,
                );
              case SearchDone(:final textless):
                state = current.copyWith(
                  searched: () => null,
                  done: true,
                  textless: textless,
                );
            }
          },
          onError: (Object _) {
            final current = state;
            if (stale()) return;
            state = current.copyWith(searched: () => null, done: true);
          },
        );
  }
}
