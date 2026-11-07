import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_size_fields.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a6-4's crop tool on [pages] (indices) of [document]: the first of them
/// in the canvas, with the panel beside it.
void showCropTool(WidgetRef ref, OpenedDocument document, List<int> pages) {
  ref
      .read(organizeCropProvider.notifier)
      .start(
        document,
        pages,
        RegionFormat.forRegion(ref.read(regionProvider).region),
      );
  if (pages.firstOrNull case final first?) {
    ref.read(viewerProvider.notifier).goToPage(first);
  }
  ref.read(shellPanelOpenProvider.notifier).open();
}

/// a6-4's right panel: Margins with Remove white margins, Page size, Apply to,
/// and Cancel and the primary button naming the count.
class CropPanel extends ConsumerStatefulWidget {
  /// The panel.
  const new({super.key, this.width});

  /// Its width; null takes the panel's.
  final double? width;

  /// a6-4's margin field: `width="{{ 112 }}"`.
  static const double marginWidth = 112;

  @override
  ConsumerState<CropPanel> createState() => _CropPanelState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

class _CropPanelState extends ConsumerState<CropPanel> {
  late final TextEditingController _range;
  bool _noContent = false;

  @override
  void initState() {
    super.initState();
    _range = TextEditingController(
      text: ref.read(organizeCropProvider)?.range ?? '',
    );
  }

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  String _sizeName(PageInfo page, RegionFormat format, LengthUnit unit) {
    bool near(PaperSize paper) =>
        (page.width - paper.widthPoints).abs() < 1 &&
        (page.height - paper.heightPoints).abs() < 1;
    return near(PaperSize.a4)
        ? 'A4'
        : near(PaperSize.letter)
        ? 'Letter'
        : format.dimensions(page.width, page.height, unit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final region = ref.watch(regionProvider);
    final format = RegionFormat.forRegion(region.region);
    final unit = region.lengthUnit;
    final session = ref.watch(organizeCropProvider);
    final view = ref.watch(viewerProvider);
    if (session == null || view == null) return const SizedBox.shrink();
    final crop = ref.read(organizeCropProvider.notifier);
    final document = view.document;
    final count = document.pages.length;
    final current = view.currentPage;
    final page = document.pages.elementAtOrNull(current);
    final handle = document.pageHandle(current);
    final margins = session.marginsOf(handle);
    final targets = session.targets(current, count);
    final tooMuch = targets == null ? null : session.tooMuch(document, targets);
    final total = targets?.length ?? 0;
    final name = ref.watch(shellDocumentsProvider).active?.name ?? '';
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );

    Widget margin(
      String label,
      double value,
      PageMargins Function(double) changed,
    ) => FmNumber(
      region: region.region,
      label: label,
      value: unit.fromPoints(value),
      precision: unitPrecision(unit),
      unit: unit.symbol,
      width: CropPanel.marginWidth,
      step: unitStep(unit),
      min: 0,
      onChanged: (typed) => crop.change(
        session.copyWith(
          keepDetected: false,
          margins: changed(typed * unit.pointsPerUnit),
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): crop.cancel},
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.cropTitle,
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
                height: FmDocPanel.headingHeight,
                padding: EdgeInsetsDirectional.only(
                  start: theme.space.space3,
                  end: theme.space.space1_5,
                ),
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(border: Border(bottom: line)),
                child: Text(
                  l10n.cropTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.panelTitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PanelSection(
                        title: l10n.cropMargins,
                        collapsible: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: theme.space.space2,
                          children: [
                            Wrap(
                              spacing: theme.space.space2_5,
                              runSpacing: theme.space.space2,
                              children: [
                                margin(
                                  l10n.cropTop,
                                  margins.top,
                                  (value) => PageMargins(
                                    top: value,
                                    bottom: margins.bottom,
                                    left: margins.left,
                                    right: margins.right,
                                  ),
                                ),
                                margin(
                                  l10n.cropBottom,
                                  margins.bottom,
                                  (value) => PageMargins(
                                    top: margins.top,
                                    bottom: value,
                                    left: margins.left,
                                    right: margins.right,
                                  ),
                                ),
                                margin(
                                  l10n.cropLeft,
                                  margins.left,
                                  (value) => PageMargins(
                                    top: margins.top,
                                    bottom: margins.bottom,
                                    left: value,
                                    right: margins.right,
                                  ),
                                ),
                                margin(
                                  l10n.cropRight,
                                  margins.right,
                                  (value) => PageMargins(
                                    top: margins.top,
                                    bottom: margins.bottom,
                                    left: margins.left,
                                    right: value,
                                  ),
                                ),
                              ],
                            ),
                            Button(
                              size: ButtonSize.sm,
                              icon: IconName.scan,
                              fullWidth: true,
                              onPressed: targets == null || targets.isEmpty
                                  ? null
                                  : () => unawaited(() async {
                                      var found = false;
                                      try {
                                        found = await crop.removeWhite(
                                          document,
                                          targets,
                                        );
                                      } on EngineException {
                                        // Says the same as no content.
                                      }
                                      if (mounted) {
                                        setState(() => _noContent = !found);
                                      }
                                    }()),
                              child: Text(l10n.cropRemoveWhite),
                            ),
                            if (_noContent)
                              Text(
                                l10n.cropNoContent,
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textSecondary,
                                ),
                              ),
                            if (tooMuch != null)
                              Text(
                                l10n.cropTooMuch(format.integer(tooMuch + 1)),
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.danger,
                                ),
                              ),
                          ],
                        ),
                      ),
                      PanelSection(
                        title: l10n.cropPageSize,
                        collapsible: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: theme.space.space2,
                          children: [
                            Select<PageSizeChoice>(
                              size: FieldSize.sm,
                              semanticLabel: l10n.cropPageSize,
                              value: session.size,
                              options: pageSizeOptions(
                                l10n,
                                format,
                                unit,
                                l10n.cropKeepSize(
                                  page == null
                                      ? ''
                                      : _sizeName(page, format, unit),
                                ),
                              ),
                              onChanged: (value) =>
                                  crop.change(session.copyWith(size: value)),
                            ),
                            if (session.size == PageSizeChoice.custom)
                              CustomSizeFields(
                                size: session.custom,
                                onChanged: (size) =>
                                    crop.change(session.copyWith(custom: size)),
                              ),
                            SegmentedControl<PageFit>(
                              semanticLabel: l10n.cropContent,
                              fullWidth: true,
                              value: session.fit,
                              disabled: session.size == PageSizeChoice.keep,
                              options: [
                                SegmentOption(
                                  value: PageFit.centre,
                                  label: l10n.cropFitCentre,
                                ),
                                SegmentOption(
                                  value: PageFit.scale,
                                  label: l10n.cropFitScale,
                                ),
                              ],
                              onChanged: (value) =>
                                  crop.change(session.copyWith(fit: value)),
                            ),
                          ],
                        ),
                      ),
                      PanelSection(
                        title: l10n.cropApplyTo,
                        collapsible: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: theme.space.space1_5,
                          children: [
                            for (final (scope, label) in [
                              (CropScope.thisPage, l10n.cropThisPage),
                              (
                                CropScope.all,
                                l10n.cropAllPages(count, format.integer(count)),
                              ),
                              (CropScope.pages, l10n.cropSomePages),
                            ])
                              Radio<CropScope>(
                                value: scope,
                                groupValue: session.scope,
                                label: label,
                                onChanged: (value) => crop.change(
                                  session.copyWith(
                                    scope: value,
                                    keepDetected: false,
                                    margins: margins,
                                  ),
                                ),
                              ),
                            // a6-4 draws no field for the range its select
                            // names; empty is every page.
                            if (session.scope == CropScope.pages)
                              TextField(
                                size: FieldSize.sm,
                                semanticLabel: l10n.cropSomePages,
                                placeholder: l10n.sourceAllPages,
                                controller: _range,
                                error: targets == null
                                    ? l10n.organizeBadRange(
                                        format.integer(count),
                                      )
                                    : null,
                                onChanged: (text) => crop.change(
                                  session.copyWith(
                                    range: text,
                                    keepDetected: false,
                                    margins: margins,
                                  ),
                                ),
                              ),
                            Select<PageParity>(
                              size: FieldSize.sm,
                              semanticLabel: l10n.cropWhichPages,
                              value: session.parity,
                              disabled: session.scope != CropScope.pages,
                              options: [
                                SelectOption(
                                  value: PageParity.all,
                                  label: l10n.cropParityAll,
                                ),
                                SelectOption(
                                  value: PageParity.odd,
                                  label: l10n.cropParityOdd,
                                ),
                                SelectOption(
                                  value: PageParity.even,
                                  label: l10n.cropParityEven,
                                ),
                              ],
                              onChanged: (value) => crop.change(
                                session.copyWith(
                                  parity: value,
                                  keepDetected: false,
                                  margins: margins,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsetsDirectional.all(theme.space.space3),
                decoration: BoxDecoration(border: Border(top: line)),
                child: Row(
                  children: [
                    Button(
                      variant: ButtonVariant.ghost,
                      onPressed: crop.cancel,
                      child: Text(l10n.organizeCancel),
                    ),
                    const Spacer(),
                    Button(
                      variant: ButtonVariant.primary,
                      onPressed:
                          targets == null ||
                              targets.isEmpty ||
                              tooMuch != null ||
                              !(session.crops || session.newSize != null)
                          ? null
                          : () => afterSigned(
                              ref,
                              document,
                              () => unawaited(
                                crop.apply(
                                  document,
                                  targets,
                                  name: name,
                                  cropStep: l10n.cropStep,
                                  sizeStep: l10n.cropSizeStep,
                                  format: format,
                                ),
                              ),
                            ),
                      child: Text(
                        session.crops || session.newSize == null
                            ? l10n.cropAction(total, format.integer(total))
                            : l10n.cropResizeAction(
                                total,
                                format.integer(total),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
