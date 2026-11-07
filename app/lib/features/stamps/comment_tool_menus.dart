import 'dart:async';
import 'dart:convert';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/stamps/create_stamp_dialog.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/features/stamps/stamp_library.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'comment_tool_menus.g.dart';

/// The Shapes menu's width (a4-1, `width: 220px`).
const double shapesMenuWidth = 220;

const String _keepId = 'keep';
const String _createId = 'create';
const String _importId = 'import';
const String _stampId = 'stamp';

/// The choices of a4-1's Shapes menu.
enum ShapeTool {
  /// A rectangle.
  rectangle('rect', IconName.square, 'R', LogicalKeyboardKey.keyR),

  /// An ellipse.
  ellipse('ellipse', IconName.ellipse, 'E', LogicalKeyboardKey.keyE),

  /// A line ending in an arrow.
  arrow('arrow', IconName.arrowUpRight, 'A', LogicalKeyboardKey.keyA),

  /// A line.
  line('line', IconName.slash, 'L', LogicalKeyboardKey.keyL),

  /// A polygon, as drawn (M4 plan, decision 6).
  polygon('polygon', IconName.pentagon, 'G', LogicalKeyboardKey.keyG);

  new(this.id, this.icon, this.shortcut, this.key);

  /// The design's id.
  final String id;

  /// The menu's icon.
  final IconName icon;

  /// The key cap in the menu.
  final String shortcut;

  /// The key that chooses it while the menu is open (decision 24).
  final LogicalKeyboardKey key;

  /// Its name.
  String label(AppLocalizations l10n) => switch (this) {
    rectangle => l10n.shapeRectangle,
    ellipse => l10n.shapeEllipse,
    arrow => l10n.shapeArrow,
    line => l10n.shapeLine,
    polygon => l10n.shapePolygon,
  };
}

/// What the tool menus remember for this session.
@immutable
final class CommentToolMenuState {
  /// The state.
  const new({
    this.shape = ShapeTool.rectangle,
    this.keepSelected = false,
    this.stamp,
    this.open,
  });

  /// The last shape chosen: the Shapes button's default (a4-1).
  final ShapeTool shape;

  /// Keep tool selected: a placed mark leaves the tool on.
  final bool keepSelected;

  /// The stamp a click on the page places.
  final StampDesign? stamp;

  /// The tool whose menu is open.
  final AnnotationTool? open;

  /// A copy with these values; [open] is always given.
  CommentToolMenuState copyWith({
    required AnnotationTool? open,
    ShapeTool? shape,
    bool? keepSelected,
    StampDesign? stamp,
  }) => CommentToolMenuState(
    shape: shape ?? this.shape,
    keepSelected: keepSelected ?? this.keepSelected,
    stamp: stamp ?? this.stamp,
    open: open,
  );
}

/// The state of the Shapes and Stamp menus, as `commentToolMenusProvider`.
@Riverpod(keepAlive: true)
class CommentToolMenus extends _$CommentToolMenus {
  @override
  CommentToolMenuState build() => const CommentToolMenuState();

  /// Opens the menu of [tool].
  void show(AnnotationTool tool) => state = state.copyWith(open: tool);

  /// Closes the menu.
  void close() => state = state.copyWith(open: null);

  /// [shape] becomes the Shapes button's default.
  void chooseShape(ShapeTool shape) =>
      state = state.copyWith(open: null, shape: shape);

  /// Turns Keep tool selected over.
  void toggleKeep() =>
      state = state.copyWith(open: null, keepSelected: !state.keepSelected);

  /// A click on the page now places [stamp].
  void chooseStamp(StampDesign stamp) =>
      state = state.copyWith(open: null, stamp: stamp);
}

/// The stamps saved on this device, oldest first (a4-3's MY STAMPS), as
/// `myStampsProvider`. Settings hold each as JSON; what cannot be read is left
/// out here, and goes from the file once the list changes.
@Riverpod(keepAlive: true)
class MyStamps extends _$MyStamps {
  /// The most stamps kept.
  static const int most = 200;

  @override
  List<StampDesign> build() {
    final saved = ref.watch(settingsProvider.select((s) => s.myStamps));
    final stamps = <StampDesign>[];
    for (final text in saved.take(most)) {
      try {
        final stamp = StampDesign.fromJson(jsonDecode(text));
        if (stamp != null) stamps.add(stamp);
      } on FormatException {
        // A hand edit of the settings file: not a stamp.
      }
    }
    return stamps;
  }

  Future<void> _store(List<StampDesign> stamps) => ref
      .read(settingsProvider.notifier)
      .change(
        (settings) => settings.copyWith(
          myStamps: [for (final stamp in stamps) jsonEncode(stamp.toJson())],
        ),
      );

  /// Saves [stamp] unless the list has it; false when the list is full.
  Future<bool> add(StampDesign stamp) async {
    if (state.contains(stamp)) return true;
    if (state.length >= most) return false;
    await _store([...state, stamp]);
    return true;
  }

  /// Removes [stamp].
  Future<void> remove(StampDesign stamp) => _store([...state]..remove(stamp));
}

/// Asks for a stamp file and saves it to My stamps; a toast says why not.
Future<void> importStamp(WidgetRef ref, AppLocalizations l10n) async {
  final stamps = ref.read(myStampsProvider.notifier);
  final toasts = ref.read(toastNoticesProvider.notifier);
  final bytes = await ref
      .read(filePickerServiceProvider)
      .openStamp(
        filterLabel: l10n.stampFileFilter,
        extension: StampDesign.fileExtension,
        largest: StampDesign.largestFile,
      );
  if (bytes == null) return;
  final stamp = StampDesign.fromFile(bytes);
  if (stamp == null) {
    toasts.show(
      tone: ToastTone.danger,
      title: (l10n) => l10n.stampImportFailed,
      message: (l10n) => l10n.stampImportFailedBody,
    );
  } else if (!await stamps.add(stamp)) {
    toasts.show(tone: ToastTone.danger, title: (l10n) => l10n.stampsFull);
  }
}

/// Asks where to write [stamp] as a file (G153).
Future<void> exportStamp(
  FilePickerService picker,
  ToastNotices toasts,
  StampDesign stamp,
) async {
  // A label can hold what a file name cannot.
  final name = stamp.label.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
  final path = await picker.saveFile(
    suggestedName: '$name.${StampDesign.fileExtension}',
  );
  if (path == null) return;
  try {
    await picker.writeFile(path, stamp.toFile());
  } on Exception {
    toasts.show(
      tone: ToastTone.danger,
      title: (l10n) => l10n.stampExportFailed,
    );
  }
}

/// Opens a4-3b.
void showCreateStampDialog(WidgetRef ref, String yourName) => ref
    .read(organizeDialogProvider.notifier)
    .show(CreateStampDialog(yourName: yourName));

/// a4-1's Shapes menu, also the Shapes submenu of the overflow menu (B093).
List<MenuItem> shapeMenuItems(
  AppLocalizations l10n,
  CommentToolMenuState state,
) => [
  for (final shape in ShapeTool.values)
    MenuItem(
      id: shape.id,
      label: shape.label(l10n),
      icon: shape.icon,
      shortcut: [shape.shortcut],
      checked: shape == state.shape,
    ),
  const MenuItem.divider(),
  MenuItem(
    id: _keepId,
    label: l10n.shapesKeepTool,
    icon: IconName.pin,
    checked: state.keepSelected,
  ),
];

/// The library as a submenu of the overflow menu (B093), which no board draws.
List<MenuItem> stampMenuItems(
  AppLocalizations l10n,
  List<StampDesign> mine,
  CommentToolMenuState state,
) {
  var index = 0;
  List<MenuItem> group(String title, List<StampDesign> stamps) => [
    if (stamps.isNotEmpty) MenuItem.section(title),
    for (final stamp in stamps)
      MenuItem(
        id: '$_stampId${index++}',
        label: stamp.capitals,
        checked: stamp == state.stamp,
      ),
  ];
  return [
    ...group(l10n.stampGroupStandard, standardStamps),
    ...group(stampGroupTurkish, turkishStamps),
    ...group(l10n.stampGroupNamed, namedStamps),
    ...group(l10n.stampGroupMine, mine),
    const MenuItem.divider(),
    MenuItem(id: _createId, label: l10n.stampCreate, icon: IconName.plus),
    MenuItem(id: _importId, label: l10n.stampImport, icon: IconName.folderOpen),
  ];
}

/// The Shapes and Stamp menus for `AnnotationTools.toolMenus`. The comment tool
/// row passes these, and calls [CommentToolMenus.show] from its
/// `onToolMenuRequested` and when a press selects one of the two. [onTool]
/// makes a tool the active one; [yourName] fills name stamps.
Map<AnnotationTool, AnnotationToolMenu> commentToolMenusOf(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<AnnotationTool> onTool,
  required String yourName,
}) {
  final l10n = AppLocalizations.of(context);
  final state = ref.watch(commentToolMenusProvider);
  final mine = ref.watch(myStampsProvider);
  final menus = ref.read(commentToolMenusProvider.notifier);
  void chooseShape(ShapeTool shape) {
    menus.chooseShape(shape);
    onTool(AnnotationTool.shapes);
  }

  void chooseStamp(StampDesign stamp) {
    menus.chooseStamp(stamp);
    onTool(AnnotationTool.stamp);
  }

  void shapeChosen(MenuItem item) {
    if (item.id == _keepId) return menus.toggleKeep();
    for (final shape in ShapeTool.values) {
      if (shape.id == item.id) chooseShape(shape);
    }
  }

  final shapeItems = shapeMenuItems(l10n, state);
  return {
    AnnotationTool.shapes: AnnotationToolMenu(
      items: shapeItems,
      onSelected: shapeChosen,
      around: (button) => Popover(
        open: state.open == AnnotationTool.shapes,
        surface: false,
        onDismiss: menus.close,
        anchor: button,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            for (final shape in ShapeTool.values) {
              if (shape.key != event.logicalKey) continue;
              chooseShape(shape);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SizedBox(
            width: shapesMenuWidth,
            child: Menu(
              semanticLabel: l10n.shellAnnotationShapes,
              items: shapeItems,
              autofocus: true,
              onClose: menus.close,
              onSelected: shapeChosen,
            ),
          ),
        ),
      ),
    ),
    AnnotationTool.stamp: AnnotationToolMenu(
      items: stampMenuItems(l10n, mine, state),
      onSelected: (item) {
        switch (item.id) {
          case _createId:
            showCreateStampDialog(ref, yourName);
          case _importId:
            unawaited(importStamp(ref, l10n));
          case final id?:
            final index = int.tryParse(id.replaceFirst(_stampId, ''));
            final all = [
              ...standardStamps,
              ...turkishStamps,
              ...namedStamps,
              ...mine,
            ];
            if (index != null && index < all.length) chooseStamp(all[index]);
        }
      },
      around: (button) => Popover(
        open: state.open == AnnotationTool.stamp,
        surface: false,
        onDismiss: menus.close,
        anchor: button,
        child: StampLibrary(yourName: yourName, onChosen: chooseStamp),
      ),
    ),
  };
}
