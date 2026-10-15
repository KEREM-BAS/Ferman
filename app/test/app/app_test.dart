import 'package:ferman/app/app.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the start screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FermanApp()));
    await tester.pumpAndSettle();
    expect(find.byType(StartScreen), findsOneWidget);
    expect(find.text('Drop a PDF here'), findsOneWidget);
  });
}
