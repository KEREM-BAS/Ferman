import 'dart:math' as math;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_position_field.dart';
import 'package:ferman/features/organize/page_size_fields.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for G45's blank pages, after the last of [pages] (indices) of
/// [document].
void showInsertBlankDialog(
  WidgetRef ref,
  OpenedDocument document,
  List<int> pages,
) => ref
    .read(organizeDialogProvider.notifier)
    .show(InsertBlankDialog(document: document, pages: pages));

/// Insert blank page (G45): size, orientation, count and position.
class InsertBlankDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({required this.document, required this.pages, super.key});

  /// The document.
  final OpenedDocument document;

  /// The pages the command acts on, as indices.
  final List<int> pages;

  /// The most pages at once the engine takes.
  static const int mostPages = 10000;

  @override
  ConsumerState<InsertBlankDialog> createState() => _InsertBlankDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<OpenedDocument>('document', document))
      ..add(IterableProperty<int>('pages', pages));
  }
}

class _InsertBlankDialogState extends ConsumerState<InsertBlankDialog> {
  late final int _last = widget.pages.lastOrNull ?? 0;
  late PagePosition _position = PagePosition(page: _last);
  PageSizeChoice _size = PageSizeChoice.keep;
  late Size _custom = _pageSize;
  late bool _landscape = _pageSize.width > _pageSize.height;
  int _count = 1;

  Size get _pageSize {
    final page = widget.document.pages.elementAtOrNull(_last);
    return page == null
        ? Size(PaperSize.a4.widthPoints, PaperSize.a4.heightPoints)
        : Size(page.width, page.height);
  }

  /// The new pages' size, turned as [_landscape] says.
  Size get _chosen {
    final size = switch (_size) {
      PageSizeChoice.keep => _pageSize,
      PageSizeChoice.a4 => Size(
        PaperSize.a4.widthPoints,
        PaperSize.a4.heightPoints,
      ),
      PageSizeChoice.letter => Size(
        PaperSize.letter.widthPoints,
        PaperSize.letter.heightPoints,
      ),
      PageSizeChoice.custom => _custom,
    };
    final short = math.min(size.width, size.height);
    final long = math.max(size.width, size.height);
    return _landscape ? Size(long, short) : Size(short, long);
  }

  void _insert(String name) {
    final engine = ref.read(engineServiceProvider);
    final id = widget.document.id;
    final after = _position.after(widget.document);
    final size = _chosen;
    final count = _count;
    final dialog = ref.read(organizeDialogProvider.notifier);
    afterSigned(
      ref,
      widget.document,
      () => commitPageChange(
        ref,
        id,
        () => engine.insertBlankPages(
          id,
          after: after,
          count: count,
          width: size.width,
          height: size.height,
          name: name,
        ),
      ),
    );
    dialog.close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final region = ref.watch(regionProvider);
    final format = RegionFormat.forRegion(region.region);
    final unit = region.lengthUnit;
    final dialog = ref.read(organizeDialogProvider.notifier);
    return Dialog(
      title: l10n.insertBlankTitle,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: () => _insert(l10n.insertBlankStep),
          child: Text(l10n.insertAction(_count, format.integer(_count))),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          Select<PageSizeChoice>(
            label: l10n.insertSize,
            size: FieldSize.sm,
            value: _size,
            options: pageSizeOptions(
              l10n,
              format,
              unit,
              l10n.insertSameSize(
                format.integer(_last + 1),
                format.dimensions(_pageSize.width, _pageSize.height, unit),
              ),
            ),
            onChanged: (value) => setState(() => _size = value),
          ),
          if (_size == PageSizeChoice.custom)
            CustomSizeFields(
              size: _custom,
              onChanged: (size) => setState(() => _custom = size),
            ),
          SegmentedControl<bool>(
            semanticLabel: l10n.insertOrientation,
            fullWidth: true,
            value: _landscape,
            options: [
              SegmentOption(value: false, label: l10n.insertPortrait),
              SegmentOption(value: true, label: l10n.insertLandscape),
            ],
            onChanged: (value) => setState(() => _landscape = value),
          ),
          PagePositionField(
            value: _position,
            count: widget.document.pages.length,
            onChanged: (position) => setState(() => _position = position),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FmNumber(
              region: region.region,
              label: l10n.insertCount,
              value: _count.toDouble(),
              precision: 0,
              unit: null,
              min: 1,
              max: InsertBlankDialog.mostPages.toDouble(),
              onChanged: (value) => setState(() => _count = value.round()),
            ),
          ),
        ],
      ),
    );
  }
}
