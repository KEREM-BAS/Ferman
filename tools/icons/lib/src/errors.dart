/// The error type of the icons tool.
library;

/// A problem that stops the tool: unreadable or unexpected design sources,
/// a Lucide package that fails its pinned checks, or a broken spec.
class IconsException implements Exception {
  /// Creates an exception with a [message] meant for the person running the
  /// tool.
  new(this.message);

  /// What went wrong and, where possible, what to do about it.
  final String message;

  @override
  String toString() => message;
}
