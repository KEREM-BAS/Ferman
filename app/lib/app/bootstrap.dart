import 'package:ferman/app/app.dart';
import 'package:ferman/app/window_setup.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Initialises the platform window and runs the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpWindow();
  runApp(const ProviderScope(child: FermanApp()));
}
