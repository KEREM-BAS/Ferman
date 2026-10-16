/// A problem in the token sources that stops generation.
///
/// The generator never guesses: an unresolved `var()`, a value it cannot
/// type, a token that fits no output class or an unknown selector all end
/// the run with one of these, naming the file and line where possible.
class TokenException implements Exception {
  /// Creates an exception with a human-readable [message].
  new(this.message);

  /// What went wrong, including the source location when known.
  final String message;

  @override
  String toString() => message;
}
