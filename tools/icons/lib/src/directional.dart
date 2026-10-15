/// The icons the design mirrors under right-to-left.
library;

/// Every icon the design flips in right-to-left layouts, with where it does
/// so (docs/DESIGN_INVENTORY.md §7, "Mirrored in RTL").
///
/// The design flips icons in three ways: the Icon prop `flipRtl`
/// (`[dir="rtl"] [data-flip-rtl]` in tokens/base.css), the `flip-rtl`
/// attribute on board imports, and a `data-fm-flip` wrapper
/// (`[dir="rtl"] [data-fm-flip] svg` in ds-additions/fm-additions.css). The
/// generated `IconName.directional` flag is `true` for exactly these names,
/// and a test checks the list against the design files.
///
/// Icons that look directional but that the design never flips (send, reply,
/// list, text-cursor, arrow-left-right, volume-2, chevrons-left,
/// chevrons-right and others) stay unmirrored until the design says
/// otherwise; the Icon widget can still flip a single use explicitly.
const Map<String, String> directionalIcons = {
  'arrow-left':
      'FmPhone line 29 wraps the Android navigation icon (arrow-left, menu '
      'or x) in data-fm-flip; only arrow-left is asymmetric.',
  'arrow-right':
      "flip-rtl on Icon in '01 First run and files' line 45 and "
      "'03c Edit review and translate' line 103.",
  'chevron-left':
      "data-fm-flip in '02 View' line 138, '12 Localization' lines 106 and "
      '114, FmPhone line 25 and FmWindow line 102.',
  'chevron-right':
      'flipRtl: true on the Menu submenu arrow (_ds_bundle.js line 2679); '
      "flip-rtl in '05b Sign' line 59; data-fm-flip in '02 View' line 138, "
      "'12 Localization' lines 106 and 114, '13b Mobile tasks' line 187 and "
      'FmWindow line 102.',
  'redo-2': 'data-fm-flip in FmWindow line 77 (title-bar toolbar).',
  'skip-back': "data-fm-flip in '02 View' line 153 (read-aloud toolbar).",
  'skip-forward': "data-fm-flip in '02 View' line 153 (read-aloud toolbar).",
  'undo-2': 'data-fm-flip in FmWindow line 77 (title-bar toolbar).',
};
