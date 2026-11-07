import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where inserted pages go: before or after a page.
@immutable
final class PagePosition {
  /// Next to [page], an index.
  const new({required this.page, this.before = false});

  /// The page.
  final int page;

  /// Whether they go before it.
  final bool before;

  /// The handle of the page they follow in [document]; null puts them first.
  int? after(OpenedDocument document) => before
      ? (page == 0 ? null : document.pageHandle(page - 1))
      : document.pageHandle(page);
}

/// G45's position: Before or After, and the page.
class PagePositionField extends ConsumerWidget {
  /// The field of [value] in a document of [count] pages.
  const new({
    required this.value,
    required this.count,
    required this.onChanged,
    super.key,
  });

  /// The position.
  final PagePosition value;

  /// The document's pages.
  final int count;

  /// Called with a new position.
  final ValueChanged<PagePosition> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: theme.space.space2_5,
      children: [
        Expanded(
          child: SegmentedControl<bool>(
            semanticLabel: l10n.insertPosition,
            fullWidth: true,
            value: value.before,
            options: [
              SegmentOption(value: true, label: l10n.insertBefore),
              SegmentOption(value: false, label: l10n.insertAfter),
            ],
            onChanged: (before) =>
                onChanged(PagePosition(page: value.page, before: before)),
          ),
        ),
        FmNumber(
          region: ref.watch(regionProvider).region,
          label: l10n.insertPage,
          value: value.page + 1.0,
          precision: 0,
          unit: null,
          min: 1,
          max: count.toDouble(),
          onChanged: (page) => onChanged(
            PagePosition(page: page.round() - 1, before: value.before),
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<PagePosition>('value', value))
      ..add(IntProperty('count', count))
      ..add(
        ObjectFlagProperty<ValueChanged<PagePosition>>.has(
          'onChanged',
          onChanged,
        ),
      );
  }
}
