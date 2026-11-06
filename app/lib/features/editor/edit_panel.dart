import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/block_language.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The right panel while a text block is edited (a3-2, building block
/// `FmEditPanel.dc.html`): its heading with "Text block" and the "Edited"
/// badge, then Text, Spacing, Position and size, and Language.
///
/// Every change is one step of the history (`DocumentEditor.setBlockStyle`,
/// `moveBlock`, `resizeBlock`). Lengths show in the region's unit, the font
/// size in points. Bold and Italic turn over to a real face of the family
/// that draws the whole block ([BlockStyleInfo.boldToggle]); without one they
/// stay disabled with the reason, as Underline always is, since a font has no
/// underline to take. The font field carries f2's warning while missing-glyph
/// step 3 waits, and [EditCallouts] say what it waits for.
class FmEditPanel extends ConsumerStatefulWidget {
  /// The panel for the block being edited, [info] its style.
  const new({required this.info, super.key, this.width});

  /// The block's style as the engine reads it.
  final BlockStyleInfo info;

  /// The panel's width; null takes `--panel-w`.
  final double? width;

  /// The width of a labelled number field (`width="{{ 112 }}"`).
  static const double fieldWidth = 112;

  /// The heading's height (`height: 40px`).
  static const double headingHeight = 40;

  /// The width of the size field (`width="{{ 92 }}"`).
  static const double sizeWidth = 92;

  @override
  ConsumerState<FmEditPanel> createState() => _FmEditPanelState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<BlockStyleInfo>('info', info))
      ..add(DoubleProperty('width', width));
  }
}

class _FmEditPanelState extends ConsumerState<FmEditPanel> {
  bool _fontOpen = false;
  bool _colourOpen = false;
  List<FontCandidate> _fonts = const [];

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  /// A step's name from its page number, formatted for the region.
  String _stepName(String Function(AppLocalizations, String) name) {
    final page = ref.read(documentEditorProvider).active?.page ?? 0;
    final format = RegionFormat.forRegion(ref.read(regionProvider).region);
    return name(AppLocalizations.of(context), format.integer(page + 1));
  }

  void _style(BlockStyle style) => unawaited(
    _editor.setBlockStyle(
      style,
      name: _stepName((l10n, page) => l10n.editStepStyle(page)),
    ),
  );

  void _font(BlockFont font) => _style(BlockStyle(font: font));

  void _openFonts({required bool open}) {
    // The popovers take the focus out of the panel for a while: the block's
    // editor stays open.
    _editor.holdEditor(held: open);
    setState(() => _fontOpen = open);
    if (open) unawaited(_loadFonts());
  }

  Future<void> _loadFonts() async {
    final fonts = await _editor.blockFonts();
    if (mounted) setState(() => _fonts = fonts);
  }

  void _move(double? x, double? y) {
    final frame = widget.info.frame;
    unawaited(
      _editor.moveBlock(
        Offset(x == null ? 0 : x - frame.left, y == null ? 0 : y - frame.top),
        name: _stepName((l10n, page) => l10n.editStepMoved(page)),
      ),
    );
  }

  void _resize(Rect frame) => unawaited(
    _editor.resizeBlock(
      frame,
      name: _stepName((l10n, page) => l10n.editStepResized(page)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final info = widget.info;
    final settings = ref.watch(regionProvider);
    final region = settings.region;
    final unit = settings.lengthUnit;
    final edited = ref.watch(
      documentEditorProvider.select((s) => s.preview != null),
    );
    final warning = ref.watch(
      documentEditorProvider.select((s) => s.glyphs != null),
    );
    final callouts = ref.watch(
      documentEditorProvider.select(
        (s) =>
            s.asking != null ||
            s.glyphs != null ||
            s.notice != null ||
            (s.preview?.dependents.isNotEmpty ?? false),
      ),
    );
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final unitDigits = unit == LengthUnit.millimetre || unit == LengthUnit.point
        ? 1
        : 2;
    Widget length(String label, double points, ValueChanged<double> changed) =>
        FmNumber(
          region: region,
          label: label,
          value: unit.fromPoints(points),
          precision: unitDigits,
          unit: unit.symbol,
          width: FmEditPanel.fieldWidth,
          step: unitDigits == 1 ? 1 : 0.1,
          onChanged: (value) => changed(value * unit.pointsPerUnit),
        );
    final frame = info.frame;
    final families = {
      for (final font in _fonts)
        if (font.usable) font.family: font,
    };
    final disabledAround = Feature.blockSpacingAround.disabledReason(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final mac = platform == ShortcutPlatform.mac;
    List<String> keys(LogicalKeyboardKey key) =>
        KeyBinding(key, meta: mac, control: !mac).caps(platform);
    // The board's grid, `gap:8px 10px` with two minmax(0,1fr) cells.
    Widget cell(Widget child) => Expanded(
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );
    Widget row(Widget a, Widget b) =>
        Row(spacing: theme.space.space2_5, children: [cell(a), cell(b)]);
    // A click in the panel is no click outside the block's field.
    return TextFieldTapRegion(
      child: FocusScope(
        node: _editor.panelFocus,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: l10n.editPanelTitle,
          child: Container(
            width: widget.width ?? theme.size.panelW,
            decoration: BoxDecoration(
              color: theme.colors.surfacePanel,
              border: BorderDirectional(start: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: FmEditPanel.headingHeight,
                  padding: EdgeInsetsDirectional.only(
                    start: theme.space.space3,
                    end: theme.space.space1_5,
                  ),
                  decoration: BoxDecoration(border: Border(bottom: line)),
                  child: Row(
                    spacing: theme.space.space2,
                    children: [
                      Expanded(
                        child: Row(
                          spacing: theme.space.space2,
                          children: [
                            Flexible(
                              child: ExcludeSemantics(
                                child: Text(
                                  l10n.editPanelTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.panelTitle.copyWith(
                                    color: theme.colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (edited)
                              Badge(
                                label: l10n.editBadgeEdited,
                                tone: BadgeTone.edited,
                                dot: true,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: IconName.rotateCcw,
                        label: l10n.editPanelReset,
                        size: IconButtonSize.xs,
                        disabledReason: Feature.blockStyleReset.disabledReason(
                          context,
                        ),
                      ),
                      IconButton(
                        icon: IconName.ellipsis,
                        label: l10n.shellMore,
                        size: IconButtonSize.xs,
                        disabledReason: Feature.rightPanelSections
                            .disabledReason(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PanelSection(
                          title: l10n.editPanelText,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: PanelSection.bodyGap,
                            children: [
                              FontPicker(
                                value: info.family,
                                glyphWarning: warning,
                                open: _fontOpen,
                                onOpenChanged: (open) => _openFonts(open: open),
                                fonts: [
                                  if (!families.containsKey(info.family))
                                    FontOption(
                                      name: info.family,
                                      group: FontGroup.document,
                                    ),
                                  for (final font in families.values)
                                    FontOption(
                                      name: font.family,
                                      group: font.origin == FontOrigin.embedded
                                          ? FontGroup.document
                                          : FontGroup.system,
                                    ),
                                ],
                                documentGroupLabel: l10n.editPanelFontsDocument,
                                systemGroupLabel: l10n.editPanelFontsDevice,
                                onChanged: (name) {
                                  _openFonts(open: false);
                                  final font = families[name];
                                  if (font == null || name == info.family) {
                                    return;
                                  }
                                  _font(
                                    BlockFont(
                                      origin: font.origin,
                                      postscriptName: font.postscriptName,
                                    ),
                                  );
                                },
                              ),
                              Row(
                                spacing: theme.space.space2,
                                children: [
                                  FmNumber(
                                    region: region,
                                    value: info.size,
                                    semanticLabel: l10n.editPanelSize,
                                    width: FmEditPanel.sizeWidth,
                                    min: 1,
                                    max: 1000,
                                    step: 0.5,
                                    onChanged: (size) =>
                                        _style(BlockStyle(size: size)),
                                  ),
                                  Expanded(
                                    child: ColorPicker(
                                      value: switch (info.colour) {
                                        final colour? => Color(
                                          0xFF000000 | colour,
                                        ),
                                        null => null,
                                      },
                                      documentColors: [
                                        for (final colour
                                            in info.documentColours)
                                          Color(0xFF000000 | colour),
                                      ],
                                      open: _colourOpen,
                                      onOpenChanged: (open) {
                                        _editor.holdEditor(held: open);
                                        setState(() => _colourOpen = open);
                                      },
                                      documentColorsLabel:
                                          l10n.editPanelColoursDocument,
                                      standardColorsLabel:
                                          l10n.editPanelColoursStandard,
                                      dialogLabel: l10n.editPanelColour,
                                      onChanged: (colour) {
                                        _editor.holdEditor(held: false);
                                        setState(() => _colourOpen = false);
                                        if (colour == null) return;
                                        _style(
                                          BlockStyle(
                                            colour:
                                                colour.toARGB32() & 0xFFFFFF,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: theme.space.space0_5,
                                    children: [
                                      _StyleToggle(
                                        icon: IconName.bold,
                                        label: l10n.editPanelBold,
                                        active: info.bold,
                                        face: info.boldToggle,
                                        reason: l10n.editPanelNoBold,
                                        onFace: _font,
                                        shortcut: keys(LogicalKeyboardKey.keyB),
                                      ),
                                      _StyleToggle(
                                        icon: IconName.italic,
                                        label: l10n.editPanelItalic,
                                        active: info.italic,
                                        face: info.italicToggle,
                                        reason: l10n.editPanelNoItalic,
                                        onFace: _font,
                                        shortcut: keys(LogicalKeyboardKey.keyI),
                                      ),
                                      IconButton(
                                        icon: IconName.underline,
                                        label: l10n.editPanelUnderline,
                                        size: IconButtonSize.sm,
                                        disabledReason:
                                            l10n.editPanelNoUnderline,
                                      ),
                                    ],
                                  ),
                                  SegmentedControl<BlockAlignment>(
                                    semanticLabel: l10n.editPanelAlignment,
                                    value: info.alignment,
                                    options: [
                                      SegmentOption(
                                        value: BlockAlignment.left,
                                        icon: IconName.alignLeft,
                                        tooltip: l10n.editPanelAlignLeft,
                                      ),
                                      SegmentOption(
                                        value: BlockAlignment.center,
                                        icon: IconName.alignCenter,
                                        tooltip: l10n.editPanelAlignCenter,
                                      ),
                                      SegmentOption(
                                        value: BlockAlignment.right,
                                        icon: IconName.alignRight,
                                        tooltip: l10n.editPanelAlignRight,
                                      ),
                                      SegmentOption(
                                        value: BlockAlignment.justified,
                                        icon: IconName.alignJustify,
                                        tooltip: l10n.editPanelAlignJustify,
                                      ),
                                    ],
                                    onChanged: (alignment) => _style(
                                      BlockStyle(alignment: alignment),
                                    ),
                                  ),
                                ],
                              ),
                              if (callouts) const EditCallouts(padded: false),
                            ],
                          ),
                        ),
                        PanelSection(
                          title: l10n.editPanelSpacing,
                          child: Column(
                            spacing: theme.space.space2,
                            children: [
                              row(
                                FmNumber(
                                  region: region,
                                  label: l10n.editPanelCharacter,
                                  value: info.charSpacing,
                                  unit: '%',
                                  width: FmEditPanel.fieldWidth,
                                  min: -50,
                                  max: 200,
                                  step: 0.5,
                                  onChanged: (percent) =>
                                      _style(BlockStyle(charSpacing: percent)),
                                ),
                                FmNumber(
                                  region: region,
                                  label: l10n.editPanelLine,
                                  value: info.lineSpacing,
                                  precision: 2,
                                  unit: '',
                                  width: FmEditPanel.fieldWidth,
                                  min: 0.5,
                                  max: 10,
                                  step: 0.05,
                                  onChanged: (multiple) =>
                                      _style(BlockStyle(lineSpacing: multiple)),
                                ),
                              ),
                              row(
                                Tooltip(
                                  message: disabledAround,
                                  child: FmNumber(
                                    region: region,
                                    label: l10n.editPanelBefore,
                                    value: 0,
                                    precision: 0,
                                    width: FmEditPanel.fieldWidth,
                                    disabled: true,
                                  ),
                                ),
                                Tooltip(
                                  message: disabledAround,
                                  child: FmNumber(
                                    region: region,
                                    label: l10n.editPanelAfter,
                                    value: 0,
                                    precision: 0,
                                    width: FmEditPanel.fieldWidth,
                                    disabled: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PanelSection(
                          title: l10n.editPanelPosition,
                          child: Column(
                            spacing: theme.space.space2,
                            children: [
                              row(
                                length('X', frame.left, (x) => _move(x, null)),
                                length('Y', frame.top, (y) => _move(null, y)),
                              ),
                              row(
                                length(
                                  l10n.editPanelWidth,
                                  frame.width,
                                  (width) => _resize(
                                    Rect.fromLTWH(
                                      frame.left,
                                      frame.top,
                                      width,
                                      frame.height,
                                    ),
                                  ),
                                ),
                                length(
                                  l10n.editPanelHeight,
                                  frame.height,
                                  (height) => _resize(
                                    Rect.fromLTWH(
                                      frame.left,
                                      frame.top,
                                      frame.width,
                                      height,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const BlockLanguageSection(),
                        Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: theme.space.space3,
                            vertical: theme.space.space2_5,
                          ),
                          child: Text(
                            l10n.editPanelHint,
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bold or Italic: turns over to [face], or says why it cannot.
class _StyleToggle extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.active,
    required this.face,
    required this.reason,
    required this.onFace,
    required this.shortcut,
  });

  final IconName icon;
  final String label;
  final bool active;
  final BlockFont? face;
  final String reason;
  final ValueChanged<BlockFont> onFace;
  final List<String> shortcut;

  @override
  Widget build(BuildContext context) {
    final target = face;
    return IconButton(
      icon: icon,
      label: label,
      size: IconButtonSize.sm,
      active: active,
      shortcut: shortcut,
      disabledReason: target == null ? reason : null,
      onPressed: target == null ? null : () => onFace(target),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<IconName>('icon', icon))
      ..add(StringProperty('label', label))
      ..add(FlagProperty('active', value: active, ifTrue: 'active'))
      ..add(DiagnosticsProperty<BlockFont?>('face', face))
      ..add(StringProperty('reason', reason))
      ..add(ObjectFlagProperty<ValueChanged<BlockFont>>.has('onFace', onFace))
      ..add(IterableProperty<String>('shortcut', shortcut));
  }
}
