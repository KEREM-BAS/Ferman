import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
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
/// and the zoom is the one the view shows, also under a fit. The
/// placeholder documents keep them disabled with the future-version
/// tooltip, through the feature registry's [Feature.pageNavigation] and
/// [Feature.zoom], until documents open (W3). Then the
/// text language of the selection when there is one ([language], FmWindow
/// `statusLang`; none in M1). At the end, the active document's save state
/// through `SaveIndicator`, the saved time in the region's format; nothing
/// while the document is still opening. Region values keep their own order
/// in right-to-left text ([bidiIsolate]: "2:32 PM" never splits).
class ShellStatusBar extends ConsumerWidget {
  /// The status bar.
  const new({super.key, this.language});

  /// The language of the selected text (FmWindow `statusLang`), or null to
  /// leave it out.
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
      Feature feature,
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
      disabled: view != null && action == null,
      disabledReason: view == null ? feature.disabledReason(context) : null,
      onPressed: action,
    );

    final language = this.language;
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
                    Feature.pageNavigation,
                    IconName.chevronUp,
                    l10n.shellPreviousPage,
                    ShellCommand.previousPage,
                    view != null && view.page > 0 ? viewer.previousPage : null,
                  ),
                  button(
                    Feature.pageNavigation,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space0_5,
                children: [
                  button(
                    Feature.zoom,
                    IconName.minus,
                    l10n.shellZoomOut,
                    ShellCommand.zoomOut,
                    view == null ? null : viewer.zoomOut,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: zoomTextWidth),
                    child: Text(
                      bidiIsolate(format.percent(view?.zoom ?? 100)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  button(
                    Feature.zoom,
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
            const Spacer(),
            if (saveState != null)
              SaveIndicator(
                state: saveState,
                savedAt: document?.savedAt,
                region: region,
                savedLabel: (time) =>
                    l10n.shellSavedOnDevice(bidiIsolate(time)),
                label: switch (saveState) {
                  SaveState.unsaved => l10n.shellUnsavedChanges,
                  SaveState.saved => l10n.shellSavedOnDevice(
                    switch (document?.savedAt) {
                      final at? => bidiIsolate(format.time(at)),
                      null => '',
                    },
                  ),
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
