import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/editor/block_language.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/jobs/task_drawer.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The status bar (FmWindow `<footer>`, lines 168–178): `--statusbar-h`
/// tall on the panel surface with a subtle line above, in the caption
/// style with tabular figures.
///
/// At the start: the previous and next page buttons with "Page 1 of 3",
/// and the zoom out and in buttons around "100%", written as the region
/// writes percentages ("%100" for Türkiye, G34) (shown while the active
/// document's page count is known). With a document open
/// (`viewerProvider`) they work: the page text is a field that a click or
/// ⌘G (Ctrl+G) opens for a page number or label ([_PageField], a2-13),
/// and the zoom is the one the view shows, also under a fit; while the
/// document is not shown yet (locked) they are disabled. Then the
/// text language of the block being edited or of the canvas selection when
/// there is one ([language], FmWindow `statusLang`). At the end, the active
/// document's save state through `SaveIndicator`, the saved time in the
/// region's format; nothing while the document is still opening. Region
/// values keep their own order in right-to-left text ([bidiIsolate]: "2:32 PM"
/// never splits).
class ShellStatusBar extends ConsumerWidget {
  /// The status bar.
  const new({super.key, this.language});

  /// The language to show (FmWindow `statusLang`); null takes the selection's
  /// and leaves it out without one.
  final String? language;

  /// FmWindow's zoom readout: `min-width: 40px`.
  static const double zoomTextWidth = 40;

  /// FmWindow's language mark: a 12 px `languages` glyph at stroke 2.
  static const double markSize = 12;

  /// The stroke of [markSize] glyphs.
  static const double markStroke = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final document = ref.watch(shellDocumentsProvider).active;
    final region = ref.watch(regionProvider).region;
    final format = RegionFormat.forRegion(region);
    final find = ref.watch(
      findProvider.select(
        (find) => (searched: find.searched, pages: find.pages),
      ),
    );
    final view = ref.watch(
      viewerProvider.select(
        (view) => view == null
            ? null
            : (
                page: view.currentPage,
                count: view.pageSizes.length,
                zoom: (view.zoom * 100).round(),
              ),
      ),
    );
    final viewer = ref.read(viewerProvider.notifier);
    final pages = view?.count ?? document?.pageCount;
    final saveState = document?.saveState;

    IconButton button(
      IconName icon,
      String label,
      ShellCommand command, [
      VoidCallback? action,
    ]) => IconButton(
      icon: icon,
      label: label,
      size: IconButtonSize.xs,
      tooltipSide: TooltipSide.top,
      shortcut: command.caps(platform),
      disabled: action == null,
      onPressed: action,
    );

    final tag =
        ref.watch(documentEditorProvider.select((s) => s.language)) ??
        ref.watch(canvasSelectionProvider.select((s) => s?.language));
    // The "· spelling" a3-14 adds comes with spell-check (B150).
    final language =
        this.language ?? (tag == null ? null : blockLanguageName(context, tag));
    final jobs = ref.read(backgroundJobsProvider.notifier);
    final rows = ref.watch(backgroundJobsProvider.select((jobs) => jobs.rows));
    final running = [
      for (final row in rows)
        if (row.active) row,
    ];
    final jobLine = switch (running) {
      [final row] => taskProgressOf(
        row,
        l10n,
        format,
        jobs,
        variant: TaskProgressVariant.inline,
      ),
      [_, _, ...] => TaskProgress(
        variant: TaskProgressVariant.inline,
        icon: IconName.listChecks,
        title: l10n.tasksRunning(
          running.length,
          format.integer(running.length),
        ),
        indeterminate: true,
      ),
      _ when find.searched != null || rows.isEmpty => null,
      _ => taskProgressOf(
        rows.last,
        l10n,
        format,
        jobs,
        variant: TaskProgressVariant.inline,
      ),
    };
    return Container(
      height: theme.density.statusbarH,
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space2,
        end: theme.space.space3,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfacePanel,
        border: Border(
          top: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: theme.typography.caption.copyWith(
          color: theme.colors.textSecondary,
          fontFeatures: theme.typeScale.numericTabular,
        ),
        maxLines: 1,
        softWrap: false,
        child: Row(
          spacing: theme.space.space3,
          children: [
            if (pages != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space0_5,
                children: [
                  button(
                    IconName.chevronUp,
                    l10n.shellPreviousPage,
                    ShellCommand.previousPage,
                    view != null && view.page > 0 ? viewer.previousPage : null,
                  ),
                  button(
                    IconName.chevronDown,
                    l10n.shellNextPage,
                    ShellCommand.nextPage,
                    view != null && view.page < view.count - 1
                        ? viewer.nextPage
                        : null,
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: theme.space.space1,
                    ),
                    child: view != null
                        ? _PageField(page: view.page, count: view.count)
                        : Text(
                            l10n.shellPageOf(
                              format.integer(1),
                              format.integer(pages),
                            ),
                          ),
                  ),
                ],
              ),
              // A phone-wide window has no room for it, and pinches instead.
              if (!WindowMetrics.isPhoneWidth(MediaQuery.sizeOf(context).width))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.space.space0_5,
                  children: [
                    button(
                      IconName.minus,
                      l10n.shellZoomOut,
                      ShellCommand.zoomOut,
                      view == null ? null : viewer.zoomOut,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: zoomTextWidth,
                      ),
                      child: Text(
                        bidiIsolate(format.percent(view?.zoom ?? 100)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    button(
                      IconName.plus,
                      l10n.shellZoomIn,
                      ShellCommand.zoomIn,
                      view == null ? null : viewer.zoomIn,
                    ),
                  ],
                ),
            ],
            if (language != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space1_5,
                children: [
                  Icon(
                    IconName.languages,
                    size: markSize,
                    strokeWidth: markStroke,
                    color: theme.colors.textSecondary,
                  ),
                  Text(language),
                ],
              ),
            // The task (FmWindow `task`, B124): the jobs running, or else the
            // search, whose find bar shows its progress too, or else the
            // job that finished last. A job's line opens the drawer. FmWindow's
            // slot, so a long file name ends in an ellipsis.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: TaskProgress.inlineSlotWidth,
                  ),
                  child: switch ((jobLine, find.searched)) {
                    (final Widget line, _) => TaskDrawerOpener(
                      label: l10n.tasksOpen,
                      onPressed: jobs.toggleDrawer,
                      child: line,
                    ),
                    (_, final int searched) => TaskProgress(
                      variant: TaskProgressVariant.inline,
                      icon: IconName.search,
                      title: l10n.statusSearching,
                      detail: l10n.shellPageOf(
                        format.integer(searched),
                        format.integer(find.pages),
                      ),
                      value: find.pages == 0 ? 0 : searched / find.pages,
                      cancelLabel: l10n.findCancel,
                      onCancel: ref.read(findProvider.notifier).cancel,
                    ),
                    _ => null,
                  },
                ),
              ),
            ),
            if (saveState != null)
              SaveIndicator(
                state: saveState,
                savedAt: document?.savedAt,
                region: region,
                savedLabel: (time) =>
                    l10n.shellSavedOnDevice(bidiIsolate(time)),
                label: switch (saveState) {
                  SaveState.unsaved => l10n.shellUnsavedChanges,
                  // A document just opened has no save of this session.
                  SaveState.saved => switch (document?.savedAt) {
                    final at? => l10n.shellSavedOnDevice(
                      bidiIsolate(format.time(at)),
                    ),
                    null => l10n.shellSavedOnDeviceUndated,
                  },
                  SaveState.saving => l10n.shellSaving,
                  SaveState.error => l10n.shellSaveError,
                  SaveState.readOnly => l10n.shellReadOnly,
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('language', language, defaultValue: null));
  }
}

/// The status bar's page text as a field (a2-13, G30): "Page 2 of 3" until
/// a click or ⌘G (Ctrl+G, `pageFieldRequestProvider`) opens the number
/// for editing in a small box with the focus border. Enter goes to the
/// page number or label typed ([pageForInput]) and Escape or leaving the
/// field keeps the page; either way focus returns where it was.
class _PageField extends ConsumerStatefulWidget {
  const new({required this.page, required this.count});

  /// The current page, from 0.
  final int page;

  /// The number of pages.
  final int count;

  /// FmWindow's box: `min-width: 34px; height: 18px`.
  static const double boxWidth = 34;
  static const double boxHeight = 18;

  @override
  ConsumerState<_PageField> createState() => _PageFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('page', page))
      ..add(IntProperty('count', count));
  }
}

class _PageFieldState extends ConsumerState<_PageField> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'PageField');
  FocusNode? _returnTo;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) setState(() => _editing = false);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _edit() {
    final format = RegionFormat.forRegion(ref.read(regionProvider).region);
    _returnTo = FocusManager.instance.primaryFocus;
    _text
      ..text = format.integer(widget.page + 1)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _done({required bool go}) {
    final view = ref.read(viewerProvider);
    if (go && view != null) {
      final page = pageForInput(_text.text, view.document.pages);
      if (page != null) ref.read(viewerProvider.notifier).goToPage(page);
    }
    setState(() => _editing = false);
    final back = _returnTo;
    _returnTo = null;
    if (back != null && back.context != null) {
      back.requestFocus();
    } else {
      _focus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    ref.listen(pageFieldRequestProvider, (_, _) => _edit());
    final count = format.integer(widget.count);
    if (!_editing) {
      return Semantics(
        button: true,
        label: l10n.viewerPageNumber,
        value: l10n.shellPageOf(format.integer(widget.page + 1), count),
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: GestureDetector(
            onTap: _edit,
            child: Text(
              l10n.shellPageOf(format.integer(widget.page + 1), count),
            ),
          ),
        ),
      );
    }
    // The text around the number, as FmWindow splits `t.page` at `{p}`.
    const mark = '\u0000';
    final parts = l10n.shellPageOf(mark, count).split(mark);
    final style = DefaultTextStyle.of(context).style
        .copyWith(color: theme.colors.textPrimary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.space1,
      children: [
        if (parts.first.trim().isNotEmpty) Text(parts.first.trim()),
        Container(
          constraints: const BoxConstraints(
            minWidth: _PageField.boxWidth,
            minHeight: _PageField.boxHeight,
            maxHeight: _PageField.boxHeight,
          ),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space1,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusSm),
            ),
            border: Border.all(
              color: theme.colors.borderFocus,
              width: theme.border.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colors.borderFocus,
                spreadRadius: theme.border.borderWidth,
              ),
            ],
          ),
          child: IntrinsicWidth(
            child: Semantics(
              label: l10n.viewerPageNumber,
              textField: true,
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Actions(
                  actions: {
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (_) => _done(go: false),
                    ),
                  },
                  child: EditableText(
                    controller: _text,
                    focusNode: _focus,
                    style: style,
                    textAlign: TextAlign.center,
                    cursorColor: theme.colors.textPrimary,
                    backgroundCursorColor: theme.colors.textTertiary,
                    selectionColor: theme.colors.accentSubtle,
                    onSubmitted: (_) => _done(go: true),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (parts.last.trim().isNotEmpty) Text(parts.last.trim()),
      ],
    );
  }
}
