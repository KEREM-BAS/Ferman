import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a6-4's Page size select, which the blank page's dialog shares.
enum PageSizeChoice {
  /// The page's own size.
  keep,

  /// A4.
  a4,

  /// Letter.
  letter,

  /// What the two fields say.
  custom,
}

/// The select's options, the first named [keep].
List<SelectOption<PageSizeChoice>> pageSizeOptions(
  AppLocalizations l10n,
  RegionFormat format,
  LengthUnit unit,
  String keep,
) => [
  SelectOption(value: PageSizeChoice.keep, label: keep),
  SelectOption(
    value: PageSizeChoice.a4,
    label: l10n.organizeSizeA4(format.paperSize(PaperSize.a4, unit)),
  ),
  SelectOption(
    value: PageSizeChoice.letter,
    label: l10n.organizeSizeLetter(format.paperSize(PaperSize.letter, unit)),
  ),
  SelectOption(value: PageSizeChoice.custom, label: l10n.organizeSizeCustom),
];

/// A field's decimals in [unit].
int unitPrecision(LengthUnit unit) => switch (unit) {
  LengthUnit.millimetre || LengthUnit.point => 1,
  LengthUnit.centimetre || LengthUnit.inch => 2,
};

/// A field's step in [unit].
double unitStep(LengthUnit unit) => switch (unit) {
  LengthUnit.millimetre || LengthUnit.point => 1,
  LengthUnit.centimetre || LengthUnit.inch => 0.1,
};

/// The width and height fields of a custom size, in points.
class CustomSizeFields extends ConsumerWidget {
  /// The fields of [size].
  const new({required this.size, required this.onChanged, super.key});

  /// The size, in points.
  final Size size;

  /// Called with a new size.
  final ValueChanged<Size> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final region = ref.watch(regionProvider);
    final unit = region.lengthUnit;
    Widget field(String label, double value, ValueChanged<double> changed) =>
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => FmNumber(
              region: region.region,
              label: label,
              value: unit.fromPoints(value),
              precision: unitPrecision(unit),
              unit: unit.symbol,
              width: box.maxWidth,
              step: unitStep(unit),
              min: unit.fromPoints(smallestPageSide),
              max: unit.fromPoints(largestPageSide),
              onChanged: (typed) => changed(typed * unit.pointsPerUnit),
            ),
          ),
        );
    return Row(
      spacing: context.ferman.space.space2_5,
      children: [
        field(
          l10n.organizeWidth,
          size.width,
          (width) => onChanged(Size(width, size.height)),
        ),
        field(
          l10n.organizeHeight,
          size.height,
          (height) => onChanged(Size(size.width, height)),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Size>('size', size))
      ..add(ObjectFlagProperty<ValueChanged<Size>>.has('onChanged', onChanged));
  }
}
