import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_region.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the title bar shows between the window controls in the editor and
/// on the start screen (FmWindow `<header>`, lines 20–32), for
/// `WindowFrame.titleBarContent`:
///
/// - **Home:** the "Ferman" wordmark tab while the start screen shows
///   ([homeActive], FmWindow `homeActive`; a1-5), otherwise the small
///   house IconButton "Home" that calls [onHome].
/// - **Document tabs:** the open documents ([documents], or the shell's
///   placeholder documents of `shellDocumentsProvider` in M1) in a
///   `DocumentTabStrip` "Open documents", with the "+N" overflow button and
///   the "+" button "Open file". Both buttons are disabled with the
///   future-version tooltip until M2, and so is the close button of the
///   active clean tab, until closing documents exists (M2); their reasons
///   come from the feature registry ([Feature]).
/// - **Search** (a ghost Button with ⌘K or Ctrl+K, disabled until the
///   command palette in M4) and **Settings** (an IconButton with ⌘, or
///   Ctrl+, that calls [onOpenSettings]).
///
/// The space between the controls moves the window: the content leaves it
/// empty, so the title bar's own drag area below receives those presses.
/// The shortcut table's keys work while focus is here
/// ([ShellCommandScope]; on the start screen only Settings and Open).
class ShellTitleBarContent extends ConsumerWidget {
  /// The title bar's content.
  const new({
    required this.onOpenSettings,
    super.key,
    this.homeActive = false,
    this.documents,
    this.onHome,
    this.onDocument,
  });

  /// Whether the start screen shows: the home tab is the active tab.
  final bool homeActive;

  /// The documents to show instead of the open ones
  /// (`shellDocumentsProvider`); their tabs are inert. On the start screen
  /// ([homeActive]) the M1 placeholders show as no documents (a1-5
  /// `noTabs`).
  final ShellDocumentList? documents;

  /// Called after a tab shows its document: the start screen goes to the
  /// editor.
  final VoidCallback? onDocument;

  /// Shows the start screen; null disables the house button.
  final VoidCallback? onHome;

  /// Opens Settings, from the button and its keys.
  final VoidCallback onOpenSettings;

  /// FmWindow's 12 px Spinner "Opening" on a loading tab.
  static const double spinnerSize = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final given = this.documents;
    // The type argument keeps `??` from asking the provider for a nullable
    // list.
    final open = ref.watch<ShellDocumentList>(shellDocumentsProvider);
    final documents =
        given ??
        (homeActive && open.placeholder
            ? const ShellDocumentList(documents: [])
            : open);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final notifier = ref.read(shellDocumentsProvider.notifier);

    final home = Padding(
      padding: EdgeInsetsDirectional.only(end: theme.space.space1),
      child: homeActive
          ? const _HomeTab()
          : Center(
              child: IconButton(
                icon: IconName.house,
                label: l10n.shellHome,
                size: IconButtonSize.sm,
                onPressed: onHome,
              ),
            ),
    );

    Widget strip(double width) {
      // As many tabs as fit at their least width, then "+N" and "+" (a1-10);
      // the M1 placeholders keep their own "+3".
      final count = documents.documents.length;
      final slot = theme.size.doctabWMin + theme.space.space0_5;
      final plus = theme.density.controlHSm + theme.space.space0_5;
      int fitting(double reserve) => ((width - plus - reserve) / slot).floor();
      var fit = fitting(0);
      if (fit < count) {
        // Room for "+N" as wide as its count makes it, counted again once
        // the count is known.
        fit = fitting(_MoreDocuments.width(context, l10n, format, count - fit));
        fit = fitting(_MoreDocuments.width(context, l10n, format, count - fit));
      }
      final shown = documents.placeholder
          ? [for (var i = 0; i < count; i++) i]
          : documents.shown(fit);
      final hidden = [
        for (var i = 0; i < count; i++)
          if (!shown.contains(i)) i,
      ];
      final overflowCount = documents.overflowCount + hidden.length;
      void show(int i) {
        notifier.activate(i);
        onDocument?.call();
      }

      return DocumentTabStrip(
        semanticLabel: l10n.shellOpenDocuments,
        tabs: [
          for (final i in shown)
            _tab(
              documents.documents[i],
              key: ValueKey(i),
              active: !homeActive && i == documents.activeIndex,
              l10n: l10n,
              closeShortcut: ShellCommand.closeDocument.caps(platform),
              closeDisabledReason: Feature.closingDocuments.disabledReason(
                context,
              ),
              onPressed: given == null ? () => show(i) : null,
            ),
        ],
        overflow: overflowCount > 0
            ? _MoreDocuments(
                count: overflowCount,
                hidden: [for (final i in hidden) (i, documents.documents[i])],
                onShow: given == null ? show : null,
              )
            : null,
        trailing: IconButton(
          icon: IconName.plus,
          label: l10n.shellOpenFile,
          size: IconButtonSize.sm,
          shortcut: ShellCommand.open.caps(platform),
          onPressed: openFiles(context, ref),
          disabledReason: openFilesDisabledReason(context, ref),
        ),
      );
    }

    final tabs = LayoutBuilder(
      builder: (context, constraints) => strip(constraints.maxWidth),
    );

    final actions = Padding(
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space2,
        end: theme.space.space1_5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space0_5,
        children: [
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            icon: IconName.search,
            disabledReason: Feature.commandPalette.disabledReason(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.space2,
              children: [
                Text(l10n.shellSearch),
                if (ShellCommand.commandPalette.caps(platform) case final keys?)
                  Kbd(keys, tone: KbdTone.plain),
              ],
            ),
          ),
          IconButton(
            icon: IconName.settings,
            label: l10n.shellSettings,
            size: IconButtonSize.sm,
            shortcut: ShellCommand.settings.caps(platform),
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );

    return ShellCommandScope(
      onOpenSettings: onOpenSettings,
      home: homeActive,
      child: ShellRegion.titleBar.wrap(
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            home,
            Expanded(child: tabs),
            Center(child: actions),
          ],
        ),
      ),
    );
  }

  DocumentTab _tab(
    ShellDocument document, {
    required Key key,
    required bool active,
    required AppLocalizations l10n,
    required List<String>? closeShortcut,
    required String? closeDisabledReason,
    required VoidCallback? onPressed,
  }) => DocumentTab(
    key: key,
    name: document.name,
    unsavedLabel: l10n.shellUnsavedChanges,
    closeLabel: l10n.shellCloseDocument,
    active: active,
    unsaved: document.unsaved,
    loading: document.loading,
    icon: document.icon,
    closeShortcut: closeShortcut,
    closeDisabledReason: closeDisabledReason,
    onPressed: onPressed,
    spinner: document.loading
        ? Spinner(size: spinnerSize, semanticLabel: l10n.shellOpening)
        : null,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('homeActive', value: homeActive, ifTrue: 'home'))
      ..add(
        DiagnosticsProperty<ShellDocumentList>(
          'documents',
          documents,
          defaultValue: null,
        ),
      )
      ..add(ObjectFlagProperty<VoidCallback>.has('onHome', onHome))
      ..add(
        ObjectFlagProperty<VoidCallback>.has('onOpenSettings', onOpenSettings),
      );
  }
}

/// "+N" and its menu of the documents whose tabs do not fit (a1-10): a
/// heading with their count, each hidden document with its ⌘1…⌘9 key when
/// it has one (an unsaved one marked, as its tab is), then "Show all open
/// documents" and "Close other documents…", disabled until they ship
/// (B117, B029). Picking a document shows it.
class _MoreDocuments extends ConsumerStatefulWidget {
  const new({required this.count, required this.hidden, this.onShow});

  /// How many documents "+N" counts.
  final int count;

  /// The hidden documents with their indexes, in order.
  final List<(int, ShellDocument)> hidden;

  /// Shows the document at an index; null leaves the items inert.
  final ValueChanged<int>? onShow;

  /// The width "+N" takes for [count] in the strip, the gap before it
  /// included: the small ghost button's padding, border, label and chevron.
  static double width(
    BuildContext context,
    AppLocalizations l10n,
    RegionFormat format,
    int count,
  ) {
    final theme = context.ferman;
    final role = theme.typography.bodyStrong;
    final label = TextPainter(
      text: TextSpan(
        text: l10n.shellMoreDocumentsBadge(format.integer(count)),
        style: role.copyWith(fontSize: theme.typeScale.sizeSm),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = label.width;
    label.dispose();
    return width +
        2 * theme.space.space2 +
        2 * theme.border.borderWidth +
        theme.space.space1_5 +
        Button.iconSizeSm +
        DocumentTabStrip.overflowGap +
        theme.space.space0_5;
  }

  @override
  ConsumerState<_MoreDocuments> createState() => _MoreDocumentsState();
}

class _MoreDocumentsState extends ConsumerState<_MoreDocuments> {
  bool _open = false;
  final FocusNode _button = FocusNode(debugLabel: 'More open documents');

  @override
  void dispose() {
    _button.dispose();
    super.dispose();
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _button.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final platform = ref.watch(shortcutPlatformProvider);
    final count = format.integer(widget.count);
    final onShow = widget.onShow;
    return Popover(
      open: _open,
      surface: false,
      onDismiss: _close,
      anchor: MergeSemantics(
        child: Semantics(
          expanded: _open,
          child: Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            iconEnd: IconName.chevronDown,
            focusNode: _button,
            onPressed: () => setState(() => _open = !_open),
            child: Semantics(
              label: l10n.shellMoreDocuments(count),
              child: ExcludeSemantics(
                child: Text(l10n.shellMoreDocumentsBadge(count)),
              ),
            ),
          ),
        ),
      ),
      child: Menu(
        autofocus: true,
        semanticLabel: l10n.shellMoreDocumentsMenu,
        items: [
          MenuItem.section(l10n.shellMoreDocumentsHeading(widget.count, count)),
          for (final (i, document) in widget.hidden)
            MenuItem(
              id: '$i',
              label: document.unsaved
                  ? l10n.shellMoreDocumentsUnsaved(document.name)
                  : document.name,
              icon: document.unsaved ? IconName.filePenLine : document.icon,
              shortcut: i < documentJumps.length
                  ? documentJumps[i].caps(platform)
                  : null,
              disabled: onShow == null,
            ),
          const MenuItem.divider(),
          MenuItem(
            label: l10n.shellShowAllDocuments,
            icon: IconName.layoutGrid,
            disabled: true,
            disabledReason: Feature.showAllDocuments.disabledReason(context),
          ),
          MenuItem(
            label: l10n.shellCloseOtherDocuments,
            icon: IconName.x,
            disabled: true,
            disabledReason: Feature.closingDocuments.disabledReason(context),
          ),
        ],
        onSelected: (item) {
          _close();
          final index = int.tryParse(item.id ?? '');
          if (index != null) onShow?.call(index);
        },
        onClose: _close,
      ),
    );
  }
}

/// The active home tab: the "Ferman" wordmark on the panel surface, joined
/// to the screen below like an active document tab (FmWindow line 20:
/// 30 px tall, 8 px from the top, `margin-bottom: -1px` over the title
/// bar's line, 8 px top corners, the wordmark at 15 px).
class _HomeTab extends StatelessWidget {
  const new();

  /// `height: 30px`.
  static const double height = 30;

  /// `font-size: 15px` on `--type-wordmark`.
  static const double wordmarkSize = 15;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final side = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Transform.translate(
        offset: Offset(0, theme.border.borderWidth),
        child: Semantics(
          container: true,
          selected: true,
          label: l10n.shellHome,
          child: ExcludeSemantics(
            child: Container(
              height: height,
              padding: EdgeInsetsDirectional.only(
                start: theme.space.space2,
                end: theme.space.space3,
              ),
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: theme.colors.surfacePanel,
                border: BorderDirectional(top: side, start: side, end: side),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(theme.radius.radiusLg),
                ),
              ),
              child: Text(
                l10n.appName,
                maxLines: 1,
                style: theme.typography.wordmark.copyWith(
                  fontSize: wordmarkSize,
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
