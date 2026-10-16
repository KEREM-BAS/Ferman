/// A problem in the gen-l10n output that stops generation.
///
/// The generator never guesses: a member it cannot wrap (one that does not
/// return `String`, a concrete member, a setter, an unknown parameter form)
/// ends the run with one of these, naming the member and its line.
class L10nException implements Exception {
  /// Creates an exception with a human-readable [message].
  new(this.message);

  /// What went wrong, including the source line when known.
  final String message;

  @override
  String toString() => message;
}
