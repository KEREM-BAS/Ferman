import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The save state of the current document (FmWindow `save`).
enum SaveState {
  /// Edits not saved yet: an amber dot.
  unsaved,

  /// Saved on this device, with the time.
  saved,

  /// Saving now: a spinner.
  saving,

  /// The last save failed.
  error,

  /// The document cannot be saved in place.
  readOnly,
}

/// The save state in the status bar, the DS addition `SaveIndicator`
/// (`FmWindow.dc.html` lines 173–177; `00 Fixes.dc.html` fix 4, lines
/// 67–96).
///
/// A 12 px mark and the state's text in the caption style with tabular
/// figures:
///
/// - [SaveState.unsaved]: a 7 px dot in `--warning-solid`, text in the
///   primary colour ("Unsaved changes");
/// - [SaveState.saved]: `hard-drive` ("Saved on this device · 14:32");
/// - [SaveState.saving]: [spinner], the design's 12 px Spinner ("Saving…");
/// - [SaveState.error]: `circle-alert`, text in `--danger` ("Couldn’t
///   save");
/// - [SaveState.readOnly]: `lock` ("Read-only").
///
/// Fix 4: the Save button, the tab's dot and this indicator always agree,
/// so all three read the same save state.
///
/// [label] is the localized text for [state]. For [SaveState.saved] the
/// caller formats [savedAt] from the region setting (`RegionFormat`,
/// "14:32") into it; the component library does not read the ARB files or
/// the region format, so it cannot build the text itself.
///
/// **Semantics:** a polite live region whose label is [label], so screen
/// readers announce each change (the design's `role="status"`).
class SaveIndicator extends StatelessWidget {
  /// The indicator for [state], reading [label].
  const new({
    required this.label,
    super.key,
    this.state = SaveState.unsaved,
    this.savedAt,
    this.spinner,
  });

  /// The save state shown.
  final SaveState state;

  /// When the document was last saved; the caller formats it into [label]
  /// for [SaveState.saved].
  final DateTime? savedAt;

  /// The localized text for [state], for example "Unsaved changes" or
  /// "Saved on this device · 14:32". Not a design-system prop.
  final String label;

  /// The busy mark of [SaveState.saving]: the design's 12 px Spinner,
  /// passed by the caller because it is another component. Not a
  /// design-system prop.
  final Widget? spinner;

  /// The marks' size: `size="12"` (`FmWindow.dc.html` lines 174–177).
  static const double markSize = 12;

  /// The stroke of the icon marks: `stroke-width="2"`.
  static const double markStroke = 2;

  /// The unsaved dot: `width: 7px; height: 7px`.
  static const double dotSize = 7;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final color = switch (state) {
      SaveState.unsaved => colors.textPrimary,
      SaveState.error => colors.danger,
      SaveState.saved ||
      SaveState.saving ||
      SaveState.readOnly => colors.textSecondary,
    };
    Widget icon(IconName name) =>
        Icon(name, size: markSize, strokeWidth: markStroke, color: color);
    final mark = switch (state) {
      SaveState.unsaved => SizedBox.square(
        dimension: dotSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.warningSolid,
          ),
        ),
      ),
      SaveState.saved => icon(IconName.hardDrive),
      SaveState.saving => SizedBox.square(
        dimension: markSize,
        child: spinner == null ? null : Center(child: spinner),
      ),
      SaveState.error => icon(IconName.circleAlert),
      SaveState.readOnly => icon(IconName.lock),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: DefaultTextStyle.merge(
          style: theme.typography.caption.copyWith(
            color: color,
            fontFeatures: [
              ...theme.typeScale.featuresUi,
              ...theme.typeScale.numericTabular,
            ],
          ),
          maxLines: 1,
          softWrap: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space.space1_5,
            children: [mark, Text(label)],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<SaveState>(
          'state',
          state,
          defaultValue: SaveState.unsaved,
        ),
      )
      ..add(
        DiagnosticsProperty<DateTime>('savedAt', savedAt, defaultValue: null),
      )
      ..add(StringProperty('label', label));
  }
}
