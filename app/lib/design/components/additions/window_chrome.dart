import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The desktop system whose window controls [WindowChrome] draws
/// (FmWindow `platform`: mac, win; linux added by Q12, G15).
enum WindowPlatform {
  /// macOS: the traffic lights at the start of the title bar.
  mac,

  /// Windows: 46 px caption buttons at the end of the title bar.
  win,

  /// Linux: client-side decorations with the caption buttons at the end
  /// (G15, Q12); the Windows layout until Linux boards exist.
  linux,
}

/// The window controls of the custom title bar, the DS addition
/// `WindowChrome` (`FmWindow.dc.html` lines 17–34; `--win-caption-w` and
/// `--win-close-hover` in `fm-additions.css`).
///
/// - **macOS** ([WindowPlatform.mac]): the slot of the traffic lights at
///   the start of the title bar (`padding-inline: 14px 12px`, three 12 px
///   lights 8 px apart). The real lights are native and placed in this slot
///   by the window integration, so by default the slot is empty; with
///   [paintTrafficLights] it paints the design's placeholder lights, for
///   goldens and the component gallery. They are decorative either way.
/// - **Windows** ([WindowPlatform.win]): three 46 px caption buttons that
///   fill the title bar's height at its end (minimize, maximize or restore,
///   close), drawn as the design draws them: a thin `minus`, `square` and
///   `x`, the surface tinted on hover, the close button red with a white
///   glyph on hover (`--win-close-hover`).
/// - **Linux** ([WindowPlatform.linux]): client-side decorations with the
///   caption buttons at the end (G15, Q12). Not drawn: it reuses the
///   Windows layout until the owner checks GNOME and KDE (COMPONENTS.md
///   decision 7).
///
/// [maximized] swaps the maximize glyph for restore. The callbacks are the
/// window commands; null disables a button. The component only draws the
/// controls: dragging the window, double-click to maximize, the Windows 11
/// snap layouts on hover over maximize and the native traffic lights come
/// from the window integration (phase H1), which also places this widget at
/// the start (macOS) or end (Windows, Linux) of the title bar.
///
/// **Keyboard:** the caption buttons are not Tab stops, as in native apps;
/// the window commands have shortcuts (⌘M, Alt+F4, Ctrl+Q) in the shortcut
/// table.
///
/// **Semantics:** buttons named [minimizeLabel], [maximizeLabel] (or
/// [restoreLabel] when [maximized]) and [closeLabel], which are also their
/// tooltips.
class WindowChrome extends StatelessWidget {
  /// The window controls for [platform].
  const new({
    required this.platform,
    required this.minimizeLabel,
    required this.maximizeLabel,
    required this.restoreLabel,
    required this.closeLabel,
    super.key,
    this.maximized = false,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.paintTrafficLights = false,
  });

  /// The system whose controls are drawn.
  final WindowPlatform platform;

  /// Whether the window is maximized: the maximize button shows the
  /// restore glyph and [restoreLabel].
  final bool maximized;

  /// Minimizes the window; null disables the button.
  final VoidCallback? onMinimize;

  /// Maximizes or restores the window; null disables the button.
  final VoidCallback? onMaximize;

  /// Closes the window; null disables the button.
  final VoidCallback? onClose;

  /// The localized "Minimize". Not a design-system prop.
  final String minimizeLabel;

  /// The localized "Maximize". Not a design-system prop.
  final String maximizeLabel;

  /// The localized "Restore", for a maximized window. Not a design-system
  /// prop.
  final String restoreLabel;

  /// The localized "Close" (the window, not a document). Not a
  /// design-system prop.
  final String closeLabel;

  /// Whether the macOS slot paints the design's placeholder traffic lights
  /// instead of leaving room for the native ones (goldens, the gallery).
  /// Not a design-system prop.
  final bool paintTrafficLights;

  /// The macOS close light: `#FF5F57` (`FmWindow.dc.html` line 18).
  static const Color macClose = Color(0xFFFF5F57);

  /// The macOS minimize light: `#FEBC2E`.
  static const Color macMinimize = Color(0xFFFEBC2E);

  /// The macOS zoom light: `#28C840`.
  static const Color macZoom = Color(0xFF28C840);

  /// The lights' edge: `inset 0 0 0 0.5px rgba(0,0,0,.25)`.
  static const Color macLightEdge = Color(0x40000000);

  /// The lights' edge width: `0.5px`.
  static const double macLightEdgeWidth = 0.5;

  /// A light's `width` and `height: 12px`.
  static const double macLightSize = 12;

  /// The slot's `padding-inline: 14px 12px`, start part (the end part is
  /// `space3`).
  static const double macSlotStart = 14;

  /// The glyph colour of the Windows close button on hover:
  /// `color: #FFFFFF`.
  static const Color closeHoverGlyph = Color(0xFFFFFFFF);

  /// The `minus` and `x` glyphs: 16 px at a 1 px stroke.
  static const double captionGlyphSize = 16;

  /// The stroke of the `minus` and `x` glyphs: `stroke-width="1"`.
  static const double captionGlyphStroke = 1;

  /// The `square` (maximize) glyph: 13 px.
  static const double maximizeGlyphSize = 13;

  /// The stroke of the `square` glyph: `stroke-width="1.2"`.
  static const double maximizeGlyphStroke = 1.2;

  /// The width of the macOS slot: the padding plus three lights and two
  /// 8 px gaps (78 px).
  static double macSlotWidth(FermanTheme theme) =>
      macSlotStart +
      theme.space.space3 +
      3 * macLightSize +
      2 * theme.space.space2;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    if (platform == WindowPlatform.mac) {
      if (!paintTrafficLights) {
        return SizedBox(
          width: macSlotWidth(theme),
          height: theme.density.titlebarH,
        );
      }
      Widget light(Color color) => SizedBox.square(
        dimension: macLightSize,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: macLightEdge, width: macLightEdgeWidth),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      );
      return ExcludeSemantics(
        child: SizedBox(
          height: theme.density.titlebarH,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: macSlotStart,
              end: theme.space.space3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.space2,
              children: [light(macClose), light(macMinimize), light(macZoom)],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: theme.space.space1),
      child: SizedBox(
        height: theme.density.titlebarH,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CaptionButton(
              label: minimizeLabel,
              glyph: IconName.minus,
              glyphSize: captionGlyphSize,
              glyphStroke: captionGlyphStroke,
              onPressed: onMinimize,
            ),
            _CaptionButton(
              label: maximized ? restoreLabel : maximizeLabel,
              // Restore is not drawn: two overlapping squares, as Windows.
              glyph: maximized ? IconName.copy : IconName.square,
              glyphSize: maximizeGlyphSize,
              glyphStroke: maximizeGlyphStroke,
              onPressed: onMaximize,
            ),
            _CaptionButton(
              label: closeLabel,
              glyph: IconName.x,
              glyphSize: captionGlyphSize,
              glyphStroke: captionGlyphStroke,
              onPressed: onClose,
              close: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<WindowPlatform>('platform', platform))
      ..add(FlagProperty('maximized', value: maximized, ifTrue: 'maximized'))
      ..add(
        FlagProperty(
          'paintTrafficLights',
          value: paintTrafficLights,
          ifTrue: 'paints traffic lights',
        ),
      );
  }
}

/// One Windows caption button (`FmWindow.dc.html` line 33).
class _CaptionButton extends StatefulWidget {
  const new({
    required this.label,
    required this.glyph,
    required this.glyphSize,
    required this.glyphStroke,
    required this.onPressed,
    this.close = false,
  });

  final String label;
  final IconName glyph;
  final double glyphSize;
  final double glyphStroke;
  final VoidCallback? onPressed;
  final bool close;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  // Caption buttons are not Tab stops, as in native apps.
  final FocusNode _node = FocusNode(
    debugLabel: 'WindowChrome caption',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FermanInteractive(
    focusNode: _node,
    onPressed: widget.onPressed,
    tooltip: widget.label,
    semanticLabel: widget.label,
    builder: (context, states, _) {
      final theme = context.ferman;
      final colors = theme.colors;
      final disabled = states.contains(WidgetState.disabled);
      final hovered = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      var background = const Color(0x00000000);
      var glyph = disabled ? colors.iconDisabled : colors.iconPrimary;
      if (!disabled && (hovered || pressed)) {
        if (widget.close) {
          background = colors.winCloseHover;
          glyph = WindowChrome.closeHoverGlyph;
        } else {
          background = pressed ? colors.surfacePressed : colors.surfaceHover;
        }
      }
      return FocusRing(
        visible: states.contains(WidgetState.focused),
        style: FocusRingStyle.inset,
        child: ExcludeSemantics(
          child: ColoredBox(
            color: background,
            child: SizedBox(
              width: theme.size.winCaptionW,
              child: Center(
                child: Icon(
                  widget.glyph,
                  size: widget.glyphSize,
                  strokeWidth: widget.glyphStroke,
                  color: glyph,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
