import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_screen.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';

/// The desktop artboard size.
const Size artboard = Size(1440, 900);

/// The smallest desktop window the app supports.
const Size smallWindow = Size(1024, 768);

/// The gallery as the app shows it: in English, the light theme, left to
/// right, [size] large, starting from [preview].
Widget galleryHost({
  Size size = artboard,
  GalleryPreview preview = const GalleryPreview(),
}) => ProviderScope(
  child: componentHost(
    SizedBox.fromSize(
      size: size,
      child: GalleryScreen(initialPreview: preview),
    ),
    size: size,
  ),
);

/// Sets the test view to [size] for this test.
void useView(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets entrances and fades finish. Never `pumpAndSettle`: spinners turn
/// for as long as they show.
Future<void> settleFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The scroll position of the gallery's list of sections.
ScrollPosition galleryPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(GalleryList),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;
