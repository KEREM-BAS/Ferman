/// Reads text files the same way on every checkout.
library;

import 'dart:io';

/// Returns [text] with every line ending (`\r\n` or a lone `\r`) turned into
/// `\n`.
///
/// A Windows checkout with `core.autocrlf` gives CRLF line endings to files
/// that `.gitattributes` does not pin to LF, such as the design sources. The
/// tool reads everything through this, so such a checkout produces the same
/// output and passes the same checks.
String normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Reads [file] as UTF-8 with its line endings normalized to `\n`.
String readText(File file) => normalizeNewlines(file.readAsStringSync());
