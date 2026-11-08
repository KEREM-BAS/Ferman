import 'dart:io' show Platform;

/// The name of the system's account, which the first comment offers (G46).
String accountName() {
  final environment = Platform.environment;
  return environment['USER'] ?? environment['USERNAME'] ?? '';
}
