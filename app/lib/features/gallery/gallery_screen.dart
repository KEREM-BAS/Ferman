import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_catalog.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The component gallery, `/debug/gallery` (M1 phase G10): every component
/// of the component library (`app/test/design/component_spec.json`) with
/// each variant, size and state the spec lists, one section per component
/// with its design-system source, grouped as the spec groups them, so a
/// person can compare it with the design's boards.
///
/// A debug surface, like `/debug/shell`; not shipped UI. The bar at the
/// top switches the preview's theme (light, dark, dim), density (standard,
/// touch), reduced motion, text direction and UI language (English,
/// Turkish, Arabic) for the sections only, never the app's settings
/// ([GalleryPreviewScope]), and filters by group. Hover, pressed and focus
/// are forced as the design's state sheet forces them
/// (`FermanForcedStates`); overlays are drawn inline.
///
/// The sections are built lazily as they scroll into view.
class GalleryScreen extends ConsumerStatefulWidget {
  /// The gallery, starting from [initialPreview].
  const new({super.key, this.initialPreview = const GalleryPreview()});

  /// The preview settings the gallery opens with.
  final GalleryPreview initialPreview;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<GalleryPreview>('initialPreview', initialPreview),
    );
  }
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late GalleryPreview _preview = widget.initialPreview;

  /// The group shown, or null for every group.
  GalleryGroup? _group;

  @override
  Widget build(BuildContext context) {
    final shortcuts = ref.watch(shortcutPlatformProvider);
    final group = _group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryControls(
          preview: _preview,
          group: group,
          onPreviewChanged: (preview) => setState(() => _preview = preview),
          onGroupChanged: (group) => setState(() => _group = group),
        ),
        Expanded(
          child: GalleryPreviewScope(
            preview: _preview,
            shortcuts: shortcuts,
            child: GalleryList(
              entries: [
                for (final entry in galleryEntries)
                  if (group == null || entry.group == group) entry,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The bar of preview controls, in the app's own theme and direction, so
/// it stays put while the preview changes.
class GalleryControls extends StatelessWidget {
  /// The controls for [preview] and the [group] filter.
  const new({
    required this.preview,
    required this.group,
    required this.onPreviewChanged,
    required this.onGroupChanged,
    super.key,
  });

  /// The current preview settings.
  final GalleryPreview preview;

  /// The group shown, or null for every group.
  final GalleryGroup? group;

  /// Called with new preview settings.
  final ValueChanged<GalleryPreview> onPreviewChanged;

  /// Called with the group to show, or null for every group.
  final ValueChanged<GalleryGroup?> onGroupChanged;

  /// The key of the segmented control for [label], for tests.
  static Key controlKey(String label) => ValueKey('gallery-control-$label');

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    Widget control<T>(
      String label,
      T value,
      List<SegmentOption<T>> options,
      GalleryPreview Function(T value) change,
    ) => _Control(
      label: label,
      child: SegmentedControl<T>(
        key: controlKey(label),
        options: options,
        value: value,
        semanticLabel: label,
        onChanged: (value) => onPreviewChanged(change(value)),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfacePanel,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space6,
          vertical: theme.space.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space3,
          children: [
            Text(GalleryLabels.title, style: theme.typography.dialogTitle),
            Text(
              GalleryLabels.subtitle,
              style: theme.typography.caption.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
            Wrap(
              spacing: theme.space.space6,
              runSpacing: theme.space.space3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                control(GalleryLabels.theme, preview.theme, [
                  SegmentOption(
                    value: GalleryTheme.light,
                    label: l10n.settingsThemeLight,
                  ),
                  SegmentOption(
                    value: GalleryTheme.dark,
                    label: l10n.settingsThemeDark,
                  ),
                  SegmentOption(
                    value: GalleryTheme.dim,
                    label: l10n.settingsPageDimmed,
                  ),
                ], (value) => preview.copyWith(theme: value)),
                control(GalleryLabels.density, preview.touch, const [
                  SegmentOption(
                    value: false,
                    label: GalleryLabels.densityStandard,
                  ),
                  SegmentOption(value: true, label: GalleryLabels.densityTouch),
                ], (value) => preview.copyWith(touch: value)),
                control(GalleryLabels.motion, preview.reducedMotion, const [
                  SegmentOption(
                    value: false,
                    label: GalleryLabels.motionStandard,
                  ),
                  SegmentOption(
                    value: true,
                    label: GalleryLabels.motionReduced,
                  ),
                ], (value) => preview.copyWith(reducedMotion: value)),
                control(GalleryLabels.direction, preview.direction, const [
                  SegmentOption(
                    value: TextDirection.ltr,
                    label: GalleryLabels.directionLtr,
                  ),
                  SegmentOption(
                    value: TextDirection.rtl,
                    label: GalleryLabels.directionRtl,
                  ),
                ], (value) => preview.copyWith(direction: value)),
                control(GalleryLabels.language, preview.language, [
                  for (final language in galleryLanguages)
                    SegmentOption(value: language, label: language.endonym),
                ], (value) => preview.copyWith(language: value)),
                _Control(
                  label: GalleryLabels.group,
                  child: SizedBox(
                    width: theme.size.sidebarW,
                    child: Select<int>(
                      options: [
                        const SelectOption(
                          value: 0,
                          label: GalleryLabels.allGroups,
                        ),
                        for (final group in GalleryGroup.values)
                          SelectOption(value: group.index + 1, label: group.id),
                      ],
                      value: group == null ? 0 : group!.index + 1,
                      size: FieldSize.sm,
                      semanticLabel: GalleryLabels.group,
                      onChanged: (value) => onGroupChanged(
                        value == 0 ? null : GalleryGroup.values[value - 1],
                      ),
                    ),
                  ),
                ),
              ],
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
      ..add(DiagnosticsProperty<GalleryPreview>('preview', preview))
      ..add(EnumProperty<GalleryGroup>('group', group, defaultValue: null))
      ..add(
        ObjectFlagProperty<ValueChanged<GalleryPreview>>.has(
          'onPreviewChanged',
          onPreviewChanged,
        ),
      )
      ..add(
        ObjectFlagProperty<ValueChanged<GalleryGroup?>>.has(
          'onGroupChanged',
          onGroupChanged,
        ),
      );
  }
}

/// A caption and its control.
class _Control extends StatelessWidget {
  const new({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.space2,
      children: [
        Text(
          label,
          style: theme.typography.label.copyWith(
            color: theme.colors.textTertiary,
          ),
        ),
        child,
      ],
    );
  }
}

/// The sections of [entries] under their group headings, built lazily.
class GalleryList extends StatelessWidget {
  /// Lists [entries], which come in group order.
  const new({required this.entries, super.key});

  /// The sections to show.
  final List<GalleryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final items = <Object>[];
    for (final group in GalleryGroup.values) {
      final inGroup = [
        for (final entry in entries)
          if (entry.group == group) entry,
      ];
      if (inGroup.isEmpty) continue;
      items
        ..add((group, inGroup.length))
        ..addAll(inGroup);
    }
    return ListView.builder(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space6,
        vertical: theme.space.space4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => switch (items[index]) {
        (final GalleryGroup group, final int count) => GalleryGroupHeading(
          key: GalleryGroupHeading.keyFor(group),
          group: group,
          count: count,
        ),
        final GalleryEntry entry => GallerySection(
          key: GallerySection.keyFor(entry.name),
          entry: entry,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('entries', entries.length));
  }
}

/// The heading of a group: its spec name and how many components it has.
class GalleryGroupHeading extends StatelessWidget {
  /// The heading of [group], which holds [count] sections.
  const new({required this.group, required this.count, super.key});

  /// The group.
  final GalleryGroup group;

  /// How many sections it holds.
  final int count;

  /// The key of [group]'s heading in the list.
  static Key keyFor(GalleryGroup group) =>
      ValueKey('gallery-group-${group.id}');

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: theme.space.space10,
        bottom: theme.space.space2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: theme.space.space3,
        children: [
          Text(group.id, style: theme.typography.headline),
          Text(
            GalleryLabels.componentCount(count),
            style: theme.typography.caption.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<GalleryGroup>('group', group))
      ..add(IntProperty('count', count));
  }
}

/// One component's section: its name (and Flutter name when it differs),
/// its design-system source, and its samples.
class GallerySection extends StatelessWidget {
  /// The section of [entry].
  const new({required this.entry, super.key});

  /// The component.
  final GalleryEntry entry;

  /// The key of the section of the component [name] in the list.
  static Key keyFor(String name) => ValueKey('gallery-section-$name');

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final flutterClass = entry.flutterClass;
    final mono = theme.typography.mono.copyWith(
      color: theme.colors.textTertiary,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: theme.space.space5,
          bottom: theme.space.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space4,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.space.space1,
              children: [
                Wrap(
                  spacing: theme.space.space3,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(entry.name, style: theme.typography.dialogTitle),
                    if (flutterClass != null)
                      Text(
                        GalleryLabels.named(
                          GalleryLabels.flutterClass,
                          flutterClass,
                        ),
                        style: mono,
                      ),
                  ],
                ),
                // A file reference: left to right in every UI language.
                Text(
                  entry.source,
                  style: mono,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            Builder(builder: entry.builder),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('entry', entry.name));
  }
}
