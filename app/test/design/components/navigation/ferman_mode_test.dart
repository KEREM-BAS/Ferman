import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eight modes in the drawn order with the design ids and icons', () {
    // FmWindow MODE_IDS and MODE_ICONS (G09, Q05).
    expect(FermanMode.values, hasLength(8));
    expect(
      [for (final mode in FermanMode.values) mode.id],
      [
        'view',
        'edit',
        'comment',
        'sign',
        'organize',
        'convert',
        'protect',
        'tools',
      ],
    );
    expect(
      [for (final mode in FermanMode.values) mode.icon],
      [
        IconName.bookOpen,
        IconName.filePenLine,
        IconName.messageSquare,
        IconName.signature,
        IconName.layoutGrid,
        IconName.refreshCw,
        IconName.shield,
        IconName.wrench,
      ],
    );
  });
}
