import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/stamps/stamp_clock.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The TÜRKÇE heading (a4-3): the language's own name, in every UI language.
const String stampGroupTurkish = 'TÜRKÇE';

/// a4-3's stamp library, the popover under the Stamp tool: search, the four
/// groups, and Create and Import. Each tile is a button; a stamp of My stamps
/// has a menu with Export and Delete (G153), by the secondary button or the
/// menu key.
class StampLibrary extends ConsumerStatefulWidget {
  /// The library.
  const new({required this.yourName, required this.onChosen, super.key});

  /// a4-3's `width: 440px`.
  static const double width = 440;

  /// The tile stamp's label size (`size="{{ 12 }}"`).
  static const double tileFontSize = 12;

  /// The tile's ring when selected (`0 0 0 1.5px var(--accent)`).
  static const double selectedRing = 1.5;

  /// The groups' and footer's side padding (`14px`), between two space tokens.
  static const double inset = 14;

  /// The tallest the library gets before it scrolls.
  static const double tallest = 560;

  /// Fills the name of a stamp that takes yours.
  final String yourName;

  /// Called with the stamp the user chooses.
  final ValueChanged<StampDesign> onChosen;

  @override
  ConsumerState<StampLibrary> createState() => _StampLibraryState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('yourName', yourName))
      ..add(
        ObjectFlagProperty<ValueChanged<StampDesign>>.has('onChosen', onChosen),
      );
  }
}

class _StampLibraryState extends ConsumerState<StampLibrary> {
  String _query = '';

  bool _matches(StampDesign stamp, LocaleCasing casing) {
    final query = casing.lower(_query.trim());
    if (query.isEmpty) return true;
    final own = LocaleCasing.forLocale(stamp.language.locale);
    return own.lower(stamp.label).contains(query);
  }

  void _showMenu(BuildContext context, StampDesign stamp, Offset position) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final group = Popover.groupOf(context);
    final picker = ref.read(filePickerServiceProvider);
    final toasts = ref.read(toastNoticesProvider.notifier);
    final stamps = ref.read(myStampsProvider.notifier);
    ContextMenuController().show(
      context: context,
      contextMenuBuilder: (context) => CustomSingleChildLayout(
        delegate: DesktopTextSelectionToolbarLayoutDelegate(anchor: position),
        child: Directionality(
          textDirection: direction,
          // A click here is not one outside the library.
          child: TapRegion(
            groupId: group,
            child: Menu(
              semanticLabel: stamp.capitals,
              autofocus: true,
              items: [
                MenuItem(
                  id: 'export',
                  label: l10n.stampExport,
                  icon: IconName.download,
                ),
                MenuItem(
                  id: 'delete',
                  label: l10n.stampDelete,
                  icon: IconName.trash2,
                  danger: true,
                ),
              ],
              onClose: ContextMenuController.removeAny,
              onSelected: (item) {
                ContextMenuController.removeAny();
                unawaited(
                  item.id == 'export'
                      ? exportStamp(picker, toasts, stamp)
                      : stamps.remove(stamp),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    List<StampDesign> stamps,
    String? Function(StampDesign stamp) metaOf,
    StampDesign? chosen, {
    required bool menu,
  }) {
    final theme = context.ferman;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          top: BorderSide(color: theme.colors.borderSubtle),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          StampLibrary.inset,
          theme.space.space2_5,
          StampLibrary.inset,
          StampLibrary.inset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2,
          children: [
            Text(
              title,
              style: theme.typography.label.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
            Wrap(
              spacing: theme.space.space3,
              runSpacing: theme.space.space2_5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final stamp in stamps)
                  _StampTile(
                    stamp: stamp,
                    meta: metaOf(stamp),
                    selected: stamp == chosen,
                    onPressed: () => widget.onChosen(stamp),
                    onMenu: menu
                        ? (position) => _showMenu(context, stamp, position)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final mine = ref.watch(myStampsProvider);
    final chosen = ref.watch(commentToolMenusProvider.select((s) => s.stamp));
    final now = ref.watch(stampClockProvider)();
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final groups = [
      for (final (title, stamps, menu) in [
        (casing.upper(l10n.stampGroupStandard), standardStamps, false),
        (stampGroupTurkish, turkishStamps, false),
        (casing.upper(l10n.stampGroupNamed), namedStamps, false),
        (casing.upper(l10n.stampGroupMine), mine, true),
      ])
        (
          title,
          [
            for (final stamp in stamps)
              if (_matches(stamp, casing)) stamp,
          ],
          menu,
        ),
    ].where((group) => group.$2.isNotEmpty).toList();
    final border = BoxDecoration(
      border: BorderDirectional(
        top: BorderSide(color: theme.colors.borderSubtle),
      ),
    );
    return Semantics(
      container: true,
      role: SemanticsRole.dialog,
      label: l10n.stampsTitle,
      child: Container(
        width: StampLibrary.width,
        constraints: const BoxConstraints(maxHeight: StampLibrary.tallest),
        decoration: BoxDecoration(
          color: theme.colors.surfaceRaised,
          borderRadius: BorderRadius.circular(theme.radius.radiusLg),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                theme.space.space3,
                theme.space.space3,
                theme.space.space3,
                theme.space.space2,
              ),
              child: TextField(
                size: FieldSize.sm,
                icon: IconName.search,
                autofocus: true,
                placeholder: l10n.stampsSearch,
                semanticLabel: l10n.stampsSearch,
                onChanged: (text) => setState(() => _query = text),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (title, stamps, menu) in groups)
                      _group(
                        context,
                        title,
                        stamps,
                        (stamp) => stamp.metaAt(now, format, widget.yourName),
                        chosen,
                        menu: menu,
                      ),
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.all(
                          StampLibrary.inset,
                        ),
                        child: Text(
                          l10n.stampsNoMatch,
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: border,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: StampLibrary.inset,
                  vertical: theme.space.space2_5,
                ),
                child: Row(
                  children: [
                    Button(
                      size: ButtonSize.sm,
                      icon: IconName.plus,
                      onPressed: () {
                        ref.read(commentToolMenusProvider.notifier).close();
                        showCreateStampDialog(ref, widget.yourName);
                      },
                      child: Text(l10n.stampCreate),
                    ),
                    const Spacer(),
                    Button(
                      size: ButtonSize.sm,
                      variant: ButtonVariant.ghost,
                      icon: IconName.folderOpen,
                      onPressed: () => unawaited(importStamp(ref, l10n)),
                      child: Text(l10n.stampImport),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One stamp of the library: `padding: 6px` with `--radius-sm`, tinted and
/// ringed when selected.
class _StampTile extends StatelessWidget {
  const new({
    required this.stamp,
    required this.meta,
    required this.selected,
    required this.onPressed,
    required this.onMenu,
  });

  final StampDesign stamp;
  final String? meta;
  final bool selected;
  final VoidCallback onPressed;
  final ValueChanged<Offset>? onMenu;

  KeyEventResult _onKey(BuildContext context, KeyEvent event) {
    final onMenu = this.onMenu;
    if (onMenu == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final asked =
        event.logicalKey == LogicalKeyboardKey.contextMenu ||
        (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed);
    final box = context.findRenderObject();
    if (!asked || box is! RenderBox) return KeyEventResult.ignored;
    onMenu(box.localToGlobal(box.size.center(Offset.zero)));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final onMenu = this.onMenu;
    final meta = this.meta;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKey(context, event),
      child: GestureDetector(
        onSecondaryTapUp: onMenu == null
            ? null
            : (details) => onMenu(details.globalPosition),
        child: FermanInteractive(
          onPressed: onPressed,
          selected: selected,
          semanticLabel: [stamp.capitals, ?meta].join(', '),
          builder: (context, states, child) => Container(
            padding: EdgeInsetsDirectional.all(theme.space.space1_5),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colors.surfaceSelected
                  : states.contains(WidgetState.hovered)
                  ? theme.colors.surfaceHover
                  : null,
              borderRadius: BorderRadius.circular(theme.radius.radiusSm),
              border: selected
                  ? Border.all(
                      color: theme.colors.accent,
                      width: StampLibrary.selectedRing,
                    )
                  : null,
            ),
            child: child,
          ),
          child: Stamp(
            label: stamp.label,
            tone: stamp.tone,
            meta: meta,
            rotation: 0,
            locale: stamp.language.locale,
            fontSize: StampLibrary.tileFontSize,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<StampDesign>('stamp', stamp))
      ..add(StringProperty('meta', meta))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed))
      ..add(ObjectFlagProperty<ValueChanged<Offset>?>.has('onMenu', onMenu));
  }
}
