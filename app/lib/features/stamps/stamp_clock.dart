import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stamp_clock.g.dart';

/// The time a stamp is filled with, so tests and goldens can hold it still.
@Riverpod(keepAlive: true)
DateTime Function() stampClock(Ref ref) => DateTime.now;
