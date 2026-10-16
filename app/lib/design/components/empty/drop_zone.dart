import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// What a [DropZone] shows (`DropZone.jsx` `COPY`).
enum DropZoneState {
  /// Waiting for a file: dashed border, the actions, recent files and the
  /// footnote; the default.
  idle,

  /// A file is dragged over it: solid accent border, accent-subtle fill,
  /// no actions (`.fm-drop--over`). Also entered while a drag hovers.
  over,

  /// The dropped file was not a PDF: danger border and icon
  /// (`.fm-drop--error`).
  error,
}

/// A recently opened file listed by a [DropZone] (the design's
/// `RecentFile`).
@immutable
class RecentFile {
  /// Describes a recent file.
  const new({required this.name, required this.meta, this.path});

  /// The file name.
  final String name;

  /// The short details after the name ("2 hours ago · 14 pages"), already
  /// localized and formatted for the region.
  final String meta;

  /// Where the file is; null when unknown.
  final String? path;

  @override
  bool operator ==(Object other) =>
      other is RecentFile &&
      other.name == name &&
      other.meta == meta &&
      other.path == path;

  @override
  int get hashCode => Object.hash(name, meta, path);

  @override
  String toString() => 'RecentFile($name, $meta, $path)';
}

/// The empty state that invites a PDF, the design-system `DropZone`
/// component (`components/empty/empty.css`, `.fm-drop`; `DropZone.jsx`).
///
/// A dashed 1.5 px border with 12 px corners around a 56 px icon tile, a
/// title, a subtitle, the actions — a large primary "Open" `Button`
/// ([openLabel], [onOpen], followed by [shortcut]) and a large "New"
/// button ([createLabel], [onCreate]) — the [recent] files under
/// [recentTitle], and the on-device [footnote]. At least [minHeight] tall
/// (380 px by default), the content centred; it takes the width of its
/// parent, which must be bounded.
///
/// [state] picks the look and the copy: [title] and [subtitle] in
/// [DropZoneState.idle], [overTitle] and [overSubtitle] in
/// [DropZoneState.over] (actions hidden), [errorTitle] and [errorSubtitle]
/// in [DropZoneState.error]. Every text is a parameter, localized by the
/// screen; a null text is not shown.
///
/// **Dragging.** The zone is a [DragTarget] for lists of file paths: while
/// such a drag hovers it shows [DropZoneState.over], and a drop calls
/// [onFiles]. Desktop file drops arrive through desktop_drop from M2,
/// which feeds the same paths in; until then a screen that tracks a drag
/// itself can pass `state: DropZoneState.over`.
///
/// **Disabled with a reason (G10).** With [disabledReason] the zone
/// ignores drags (a drag over it does not enter the over state), and the
/// Open and New buttons and the recent rows are disabled but focusable,
/// with the reason as tooltip and semantics hint. The New button shows
/// when [onCreate] is set or the zone is disabled with a reason.
///
/// For screen readers it is a region named by the title, which is also a
/// heading; Tab reaches the buttons and the recent files.
class DropZone extends StatelessWidget {
  /// Creates a drop zone.
  const new({
    super.key,
    this.state = DropZoneState.idle,
    this.title,
    this.subtitle,
    this.onOpen,
    this.onCreate,
    this.shortcut = const ['⌘', 'O'],
    this.recent = const [],
    this.onOpenRecent,
    this.footnote,
    this.onFiles,
    this.minHeight,
    this.disabledReason,
    this.overTitle,
    this.overSubtitle,
    this.errorTitle,
    this.errorSubtitle,
    this.openLabel,
    this.createLabel,
    this.recentTitle,
  });

  /// `.fm-drop` `min-height: 380px`.
  static const double defaultMinHeight = 380;

  /// `.fm-drop` `padding: 48px 32px`: the vertical padding.
  static const double paddingY = 48;

  /// `.fm-drop` `padding: 48px 32px`: the horizontal padding.
  static const double paddingX = 32;

  /// `.fm-drop__icon` `width` and `height`.
  static const double tileSize = 56;

  /// `DropZone.jsx` state icon size.
  static const double iconSize = 24;

  /// `.fm-drop__text` `max-width: 420px`.
  static const double textMaxWidth = 420;

  /// `.fm-drop__recent` `max-width: 440px`.
  static const double recentMaxWidth = 440;

  /// `.fm-drop__file` `height: 36px`.
  static const double recentRowHeight = 36;

  /// `DropZone.jsx` recent-file icon size.
  static const double recentIconSize = 16;

  /// `DropZone.jsx` footnote icon size.
  static const double footnoteIconSize = 14;

  /// The shortcut after the Open label: `opacity: 0.75`.
  static const double shortcutOpacity = 0.75;

  /// Chromium draws the 1.5 px dashed border as 3 px dashes …
  static const double dashLength = 3;

  /// … with 2 px gaps (the `a1-5` render).
  static const double dashGap = 2;

  /// The look and copy; [DropZoneState.over] is also shown while a drag
  /// hovers.
  final DropZoneState state;

  /// The idle title ("Drop a PDF here").
  final String? title;

  /// The idle subtitle.
  final String? subtitle;

  /// Called by the Open button.
  final VoidCallback? onOpen;

  /// Called by the New button; null hides it unless [disabledReason] is
  /// set.
  final VoidCallback? onCreate;

  /// The Open shortcut's key caps, already resolved for the platform,
  /// shown after [openLabel].
  final List<String> shortcut;

  /// The recent files listed in the idle state. Each row is keyed by its
  /// file's [RecentFile.path] (its [RecentFile.name] when the path is
  /// unknown), so a row keeps its focus and hover when the list changes;
  /// the entries must be unique by that key.
  final List<RecentFile> recent;

  /// Called with the recent file the user picks.
  final ValueChanged<RecentFile>? onOpenRecent;

  /// The note at the bottom in the idle state ("Files stay on this
  /// device. Ferman never uploads your documents.").
  final String? footnote;

  /// Called with the dropped file paths.
  final ValueChanged<List<String>>? onFiles;

  /// The minimum height; null is [defaultMinHeight].
  final double? minHeight;

  /// Why drops, Open, New and the recent files are disabled (G10).
  final String? disabledReason;

  /// The title while a drag hovers ("Release to open"). Not a
  /// design-system prop: the design hard-codes the copy.
  final String? overTitle;

  /// The subtitle while a drag hovers. Not a design-system prop.
  final String? overSubtitle;

  /// The title of the error state ("That file isn’t a PDF"). Not a
  /// design-system prop.
  final String? errorTitle;

  /// The subtitle of the error state. Not a design-system prop.
  final String? errorSubtitle;

  /// The Open button's label ("Open a PDF"); null hides the button. Not a
  /// design-system prop.
  final String? openLabel;

  /// The New button's label ("New blank PDF"); null hides the button. Not
  /// a design-system prop.
  final String? createLabel;

  /// The heading above [recent] ("Recent"). Not a design-system prop.
  final String? recentTitle;

  /// [shortcut] as the design writes it after the Open label: the macOS
  /// symbols run together ("⌘O"); word key caps take a plus ("Ctrl+O").
  String get shortcutText => shortcut.every((key) => key.characters.length == 1)
      ? shortcut.join()
      : shortcut.join('+');

  @override
  Widget build(BuildContext context) => DragTarget<List<String>>(
    onWillAcceptWithDetails: (_) => disabledReason == null,
    onAcceptWithDetails: (details) => onFiles?.call(details.data),
    builder: (context, candidates, _) =>
        _zone(context, candidates.isNotEmpty ? DropZoneState.over : state),
  );

  Widget _zone(BuildContext context, DropZoneState shown) {
    final theme = context.ferman;
    final colors = theme.colors;
    final (heading, sub, glyph, iconColor) = switch (shown) {
      DropZoneState.idle => (
        title,
        subtitle,
        IconName.fileText,
        colors.iconSecondary,
      ),
      DropZoneState.over => (
        overTitle,
        overSubtitle,
        IconName.download,
        colors.textAccent,
      ),
      DropZoneState.error => (
        errorTitle,
        errorSubtitle,
        IconName.circleAlert,
        colors.danger,
      ),
    };
    final borderColor = switch (shown) {
      DropZoneState.idle => colors.borderStrong,
      DropZoneState.over => colors.accent,
      DropZoneState.error => colors.dangerBorder,
    };
    final borderWidth = theme.border.borderWidthStrong;
    final radius = theme.radius.radiusXl;
    final disabledWithReason = disabledReason != null;

    final tile = Container(
      width: tileSize,
      height: tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        // `box-shadow: 0 0 0 1px var(--border-subtle), var(--shadow-sm)` in
        // reverse: CSS paints the first layer on top, Flutter the last, so
        // the ring comes last to stay over the small shadow.
        boxShadow: [
          ...theme.elevation.shadowSm,
          BoxShadow(
            color: colors.borderSubtle,
            spreadRadius: theme.border.borderWidth,
          ),
        ],
      ),
      child: Icon(glyph, size: iconSize, color: iconColor),
    );

    // A block with nothing in it is left out, so it adds no gap.
    final text = heading == null && sub == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: textMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.space1_5,
              children: [
                if (heading != null)
                  Semantics(
                    header: true,
                    child: Text(
                      heading,
                      textAlign: TextAlign.center,
                      style: theme.typography.body.copyWith(
                        fontSize: theme.typeScale.size2xl,
                        height: theme.typeScale.height2xl,
                        fontWeight: theme.typeScale.weightSemibold,
                        letterSpacing:
                            theme.typeScale.trackingTight *
                            theme.typeScale.size2xl,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                if (sub != null)
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: theme.typography.prose.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          );

    final showCreate =
        createLabel != null && (onCreate != null || disabledWithReason);
    final actions =
        shown == DropZoneState.over || (openLabel == null && !showCreate)
        ? null
        : Wrap(
            alignment: WrapAlignment.center,
            spacing: theme.space.space2,
            runSpacing: theme.space.space2,
            children: [
              if (openLabel != null)
                Button(
                  variant: ButtonVariant.primary,
                  size: ButtonSize.lg,
                  icon: IconName.folderOpen,
                  onPressed: onOpen,
                  disabled: disabledWithReason,
                  disabledReason: disabledReason,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(openLabel!),
                      if (shortcut.isNotEmpty)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: theme.space.space1,
                          ),
                          child: Opacity(
                            opacity: shortcutOpacity,
                            child: Text(
                              shortcutText,
                              // Key caps read left to right in every UI
                              // language: "⌘O", never "O⌘".
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontWeight: theme.typeScale.weightRegular,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (showCreate)
                Button(
                  size: ButtonSize.lg,
                  icon: IconName.filePlus2,
                  onPressed: onCreate,
                  disabled: disabledWithReason,
                  disabledReason: disabledReason,
                  child: Text(createLabel!),
                ),
            ],
          );

    final recentList = recent.isEmpty || shown != DropZoneState.idle
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(top: theme.space.space2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: recentMaxWidth),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.space0_5,
                  children: [
                    if (recentTitle != null)
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          theme.space.space2,
                          0,
                          theme.space.space2,
                          theme.space.space1,
                        ),
                        child: Text(
                          recentTitle!,
                          textAlign: TextAlign.start,
                          style: theme.typography.label.copyWith(
                            color: colors.textTertiary,
                            letterSpacing:
                                theme.typeScale.trackingLabel *
                                (theme.typography.label.fontSize ?? 0),
                          ),
                        ),
                      ),
                    // Keyed like the design's rows (`key: f.name`), so a
                    // row's focus and hover stay with its file.
                    for (final file in recent)
                      KeyedSubtree(
                        key: ValueKey<String>(file.path ?? file.name),
                        child: _recentRow(context, file),
                      ),
                  ],
                ),
              ),
            ),
          );

    final foot = footnote == null || shown != DropZoneState.idle
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space.space1_5,
            children: [
              Icon(
                IconName.hardDrive,
                size: footnoteIconSize,
                color: colors.textTertiary,
              ),
              Flexible(
                child: Text(
                  footnote!,
                  // `.fm-drop` `text-align: center`, inherited.
                  textAlign: TextAlign.center,
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          );

    // `.fm-drop` transitions only its fill and border colours: the minimum
    // height applies at once, outside the animated fill.
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? defaultMinHeight),
      child: AnimatedContainer(
        duration: theme.motion.durBase,
        curve: theme.motion.easeOut,
        width: double.infinity,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: paddingX + borderWidth,
          vertical: paddingY + borderWidth,
        ),
        decoration: BoxDecoration(
          color: shown == DropZoneState.over
              ? colors.accentSubtle
              : const Color(0x00000000),
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: theme.space.space4,
          children: [tile, ?text, ?actions, ?recentList, ?foot],
        ),
      ),
    );

    final label = heading ?? '';
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: label.isEmpty ? null : SemanticsRole.region,
      label: label.isEmpty ? null : label,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: borderColor),
        duration: theme.motion.durBase,
        curve: theme.motion.easeOut,
        builder: (context, color, child) => CustomPaint(
          foregroundPainter: DropZoneBorderPainter(
            color: color ?? borderColor,
            width: borderWidth,
            radius: radius,
            dashed: shown != DropZoneState.over,
          ),
          child: child,
        ),
        child: content,
      ),
    );
  }

  Widget _recentRow(BuildContext context, RecentFile file) {
    final open = onOpenRecent;
    return FermanInteractive(
      onPressed: open == null ? null : () => open(file),
      disabled: disabledReason != null,
      disabledReason: disabledReason,
      builder: (context, states, _) {
        final theme = context.ferman;
        final colors = theme.colors;
        final disabled = states.contains(WidgetState.disabled);
        final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
        return FocusRing(
          visible: states.contains(WidgetState.focused),
          style: FocusRingStyle.inset,
          borderRadius: radius,
          // `.fm-drop__file` has no transition: the hover fill shows at once.
          child: Container(
            height: recentRowHeight,
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.space.space2,
            ),
            decoration: BoxDecoration(
              color: states.contains(WidgetState.hovered)
                  ? colors.surfaceHover
                  : const Color(0x00000000),
              borderRadius: radius,
            ),
            child: Row(
              spacing: theme.space.space2_5,
              children: [
                Icon(
                  IconName.fileText,
                  // recentIconSize, the Icon default.
                  color: disabled ? colors.iconDisabled : colors.iconSecondary,
                ),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(
                      color: disabled
                          ? colors.textDisabled
                          : colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  file.meta,
                  softWrap: false,
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                    fontFeatures: [
                      ...theme.typeScale.featuresUi,
                      ...theme.typeScale.numericTabular,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<DropZoneState>(
          'state',
          state,
          defaultValue: DropZoneState.idle,
        ),
      )
      ..add(StringProperty('title', title, defaultValue: null))
      ..add(StringProperty('subtitle', subtitle, defaultValue: null))
      ..add(ObjectFlagProperty<VoidCallback>.has('onOpen', onOpen))
      ..add(ObjectFlagProperty<VoidCallback>.has('onCreate', onCreate))
      ..add(IterableProperty<String>('shortcut', shortcut))
      ..add(IterableProperty<RecentFile>('recent', recent))
      ..add(StringProperty('footnote', footnote, defaultValue: null))
      ..add(DoubleProperty('minHeight', minHeight, defaultValue: null))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      );
  }
}

/// Paints a [DropZone]'s border: a [width] stroke inside the canvas with
/// corners of [radius], dashed ([DropZone.dashLength] on,
/// [DropZone.dashGap] off) unless [dashed] is false.
class DropZoneBorderPainter extends CustomPainter {
  /// Creates the painter.
  const new({
    required this.color,
    required this.width,
    required this.radius,
    required this.dashed,
  });

  /// The stroke colour.
  final Color color;

  /// The stroke width.
  final double width;

  /// The outer corner radius.
  final double radius;

  /// Whether the stroke is dashed (idle, error) or solid (over).
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final box = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(inset),
      Radius.circular(math.max(0, radius - inset)),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (!dashed) {
      canvas.drawRRect(box, paint);
      return;
    }
    for (final metric in (Path()..addRRect(box)).computeMetrics()) {
      for (
        var at = 0.0;
        at < metric.length;
        at += DropZone.dashLength + DropZone.dashGap
      ) {
        canvas.drawPath(
          metric.extractPath(
            at,
            math.min(at + DropZone.dashLength, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DropZoneBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.radius != radius ||
      oldDelegate.dashed != dashed;
}
