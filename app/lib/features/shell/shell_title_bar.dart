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
///   active clean tab, until closing documents exists (M2).
/// - **Search** (a ghost Button with ⌘K or Ctrl+K, disabled until the
///   command palette in M4) and **Settings** (an IconButton with ⌘, or
///   Ctrl+, that calls [onOpenSettings]; disabled with the future-version
///   tooltip while that is null).
///
/// The space between the controls moves the window: the content leaves it
/// empty, so the title bar's own drag area below receives those presses.
/// The shortcut table's keys work while focus is here
/// ([ShellCommandScope]; on the start screen only Settings).
class ShellTitleBarContent extends ConsumerWidget {
  /// The title bar's content.
  const new({
    super.key,
    this.homeActive = false,
    this.documents,
    this.onHome,
    this.onOpenSettings,
  });

  /// Whether the start screen shows: the home tab is the active tab.
  final bool homeActive;

  /// The open documents to show instead of the shell's placeholders
  /// (`shellDocumentsProvider`); their tabs are inert. The start screen
  /// passes an empty list, since no document opens before M2 (a1-5
  /// `noTabs`).
  final ShellDocumentList? documents;

  /// Shows the start screen; null disables the house button.
  final VoidCallback? onHome;

  /// Opens Settings; null disables the button and its keys.
  final VoidCallback? onOpenSettings;

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
    final documents =
        given ?? ref.watch<ShellDocumentList>(shellDocumentsProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final future = futureVersionReason(context);
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

    final overflowCount = documents.overflowCount;
    final tabs = DocumentTabStrip(
      semanticLabel: l10n.shellOpenDocuments,
      tabs: [
        for (var i = 0; i < documents.documents.length; i++)
          _tab(
            documents.documents[i],
            active: !homeActive && i == documents.activeIndex,
            l10n: l10n,
            closeShortcut: ShellCommand.closeDocument.caps(platform),
            closeDisabledReason: future,
            onPressed: given == null ? () => notifier.activate(i) : null,
          ),
      ],
      overflow: overflowCount > 0
          ? Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              iconEnd: IconName.chevronDown,
              disabledReason: future,
              child: Semantics(
                label: l10n.shellMoreDocuments(format.integer(overflowCount)),
                child: ExcludeSemantics(
                  child: Text(
                    l10n.shellMoreDocumentsBadge(format.integer(overflowCount)),
                  ),
                ),
              ),
            )
          : null,
      trailing: IconButton(
        icon: IconName.plus,
        label: l10n.shellOpenFile,
        size: IconButtonSize.sm,
        shortcut: ShellCommand.open.caps(platform),
        disabledReason: future,
      ),
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
            disabledReason: future,
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
            disabledReason: onOpenSettings == null ? future : null,
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
    required bool active,
    required AppLocalizations l10n,
    required List<String>? closeShortcut,
    required String closeDisabledReason,
    required VoidCallback? onPressed,
  }) => DocumentTab(
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
