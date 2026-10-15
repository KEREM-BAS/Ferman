import 'package:ferman/app/app.dart';
import 'package:ferman/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the built app starts and shows the root widget', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(FermanApp), findsOneWidget);
  });
}
