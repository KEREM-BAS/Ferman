import 'package:flutter/widgets.dart';

/// Locale-aware case mapping for UI text: [upper], [lower] and [capitalize]
/// (ARCHITECTURE.md §11.2, ADR 0014).
///
/// Dart's `String.toUpperCase` ignores the language, so Turkish "imzala"
/// becomes "IMZALA" instead of "İMZALA". Every uppercase label goes through
/// this class. Casing follows the language of the text, which for
/// UI strings is the UI locale ([LocaleCasing.of]); numbers, dates and units
/// follow the region setting instead (`region.dart`, `format.dart`).
///
/// It implements Unicode 15.0 full case mapping with every rule of
/// SpecialCasing.txt:
///
/// - **Every language:** the simple mappings of UnicodeData.txt, the
///   unconditional full mappings of SpecialCasing.txt ("ß" → "SS",
///   "ﬁ" → "FI", "ŉ" → "ʼN", the Greek iota subscripts, and "İ" → i +
///   U+0307) and Final_Sigma ("ΟΔΟΣ" → "οδος"). The Dart VM's own tables
///   have neither the full mappings nor the case pairs added after Unicode
///   6 (Cherokee, Georgian Mtavruli, Latin Extended-D and others); the
///   tables below add both, so every platform gives the same result.
/// - **Turkish and Azerbaijani** (`tr`, `az`): i → İ, ı → I, I → ı, İ → i.
///   "I" followed by U+0307 COMBINING DOT ABOVE lowercases to plain "i"
///   (After_I and Not_Before_Dot).
/// - **Lithuanian** (`lt`): lowercase I, J and Į keep an explicit U+0307
///   when another accent above follows (More_Above); Ì, Í and Ĩ lowercase
///   to i + U+0307 + the accent; upper and title case drop a U+0307 that
///   follows a soft-dotted letter such as i or j (After_Soft_Dotted).
///
/// Not implemented, because they are CLDR tailorings outside
/// SpecialCasing.txt and none of the 21 UI languages needs them: Greek
/// uppercase without accents (`el`), Dutch "IJ" title case (`nl`) and
/// Armenian "և" (`hy`). The design uses sentence case, so there is no
/// title-casing of every word, only [capitalize].
///
/// The context rules read character properties from Unicode 15.0 tables
/// derived from DerivedCoreProperties.txt, PropList.txt and
/// UnicodeData.txt: Cased and Soft_Dotted in full; Case_Ignorable and the
/// canonical combining classes only in the blocks that sit next to Latin,
/// Greek and Cyrillic letters (each table names its blocks). Outside those
/// blocks a character counts as a starter that is not case-ignorable; such
/// marks never follow I, J or Σ in real text.
///
/// ICU is the reference. When this class was written it matched ICU4C 74.2
/// exactly for every code point alone (upper, lower and title case, in
/// root, tr and lt) and for 30,000 random context strings per locale;
/// `test/l10n/casing_icu_test.dart` keeps 160 of those strings. ADR 0014's
/// table test against the engine's ICU4X follows when ICU4X arrives (M2).
@immutable
final class LocaleCasing {
  const new _(this._rules);

  /// The rules for [locale]'s language.
  factory forLocale(Locale locale) =>
      LocaleCasing.forLanguage(locale.languageCode);

  /// The rules for a language code, with or without script and region
  /// subtags (`tr`, `tr-TR`, `az_Latn`): Turkish and Azerbaijani (`tr`,
  /// `tur`, `az`, `aze`) take [turkic], Lithuanian (`lt`, `lit`) takes
  /// [lithuanian], and every other language takes [root].
  factory forLanguage(String language) {
    final code = language.split(_subtagSeparator).first.toLowerCase();
    return switch (code) {
      'tr' || 'tur' || 'az' || 'aze' => turkic,
      'lt' || 'lit' => lithuanian,
      _ => root,
    };
  }

  /// The rules for the UI locale at [context].
  factory of(BuildContext context) =>
      LocaleCasing.forLocale(Localizations.localeOf(context));

  /// The default Unicode case mapping, for every language without its own
  /// rules (English keeps i ↔ I).
  static const LocaleCasing root = LocaleCasing._(_Rules.root);

  /// The Turkish and Azerbaijani rules: dotted i ↔ İ, dotless ı ↔ I.
  static const LocaleCasing turkic = LocaleCasing._(_Rules.turkic);

  /// The Lithuanian rules for the dot above i and j.
  static const LocaleCasing lithuanian = LocaleCasing._(_Rules.lithuanian);

  static final RegExp _subtagSeparator = RegExp('[-_]');

  final _Rules _rules;

  @override
  String toString() => 'LocaleCasing.${_rules.name}';

  /// [text] in upper case: Turkish "imzala" → "İMZALA", "ılık" → "ILIK";
  /// German "Straße" → "STRASSE".
  String upper(String text) {
    if (_rules == _Rules.root && _isAscii(text)) return text.toUpperCase();
    return _mapText(
      text,
      (index, cp) => _upperSpecial(text, index, cp),
      (run) => run.toUpperCase(),
    );
  }

  /// [text] in lower case: Turkish "İSTANBUL" → "istanbul", "I" → "ı";
  /// Greek "ΟΔΟΣ" → "οδος".
  String lower(String text) {
    if (_rules == _Rules.root && _isAscii(text)) return text.toLowerCase();
    return _mapText(
      text,
      (index, cp) => _lowerSpecial(text, index, cp),
      (run) => run.toLowerCase(),
    );
  }

  /// [text] with its first letter in title case and everything else
  /// unchanged, for sentence-case labels: Turkish "istanbul" → "İstanbul",
  /// "ǆep" → "ǅep", "ﬁle" → "File".
  ///
  /// Leading spaces, punctuation and combining marks are skipped, so the
  /// first letter after them changes ("¿qué?" → "¿Qué?", "«ilk»" → "«İlk»"
  /// in Turkish). They are: ASCII characters other than letters and digits,
  /// U+00A0 to U+00BF except ª, µ and º, General Punctuation (U+2000 to
  /// U+206F), CJK Symbols and Punctuation (U+3000 to U+303F) and the marks
  /// of the combining-class tables below. Anything else ends the search: a
  /// leading digit stays first ("3 sayfa" is unchanged), and a letter
  /// without case (Arabic, CJK) is left as it is. For single characters
  /// this matches ICU's title case with its default (CLDR) adjustment.
  String capitalize(String text) {
    var start = 0;
    while (start < text.length) {
      final cp = _codePointAt(text, start);
      if (!_skipsBeforeFirstLetter(cp) && _combiningClass(cp) == 0) break;
      start += _width(cp);
    }
    if (start >= text.length) return text;
    final cp = _codePointAt(text, start);
    final end = start + _width(cp);
    final title = _title(cp);
    if (_rules == _Rules.lithuanian && _isSoftDotted(cp)) {
      // Title case drops the U+0307 of the first letter's combining
      // sequence (After_Soft_Dotted).
      var next = end;
      while (next < text.length) {
        final mark = _codePointAt(text, next);
        if (mark == _combiningDotAbove) {
          return '${text.substring(0, start)}$title'
              '${text.substring(end, next)}${text.substring(next + 1)}';
        }
        final ccc = _combiningClass(mark);
        if (ccc == 0 || ccc == _cccAbove) break;
        next += _width(mark);
      }
    }
    return '${text.substring(0, start)}$title${text.substring(end)}';
  }

  /// The upper-case mapping of [cp] at [index] when it differs from what
  /// `String.toUpperCase` gives on every platform, else null.
  String? _upperSpecial(String text, int index, int cp) {
    switch (_rules) {
      case _Rules.turkic:
        if (cp == _smallI) return '\u0130';
      case _Rules.lithuanian:
        if (cp == _combiningDotAbove && _afterSoftDotted(text, index)) {
          return '';
        }
      case _Rules.root:
        break;
    }
    final full = _fullMappings[cp];
    if (full != null) return full.upper;
    final delta = _deltaFor(cp);
    if (delta == null) return null;
    final mapped = delta.upperOf(cp);
    return mapped == cp ? null : String.fromCharCode(mapped);
  }

  /// The lower-case mapping of [cp] at [index] when it differs from what
  /// `String.toLowerCase` gives on every platform, else null.
  String? _lowerSpecial(String text, int index, int cp) {
    switch (_rules) {
      case _Rules.turkic:
        if (cp == _capitalIWithDot) return 'i';
        if (cp == _combiningDotAbove && _afterCapitalI(text, index)) return '';
        // An I before a dot above lowercases to i; the dot goes (After_I).
        if (cp == _capitalI && !_beforeDotAbove(text, index)) return '\u0131';
      case _Rules.lithuanian:
        switch (cp) {
          case 0x0049 || 0x004A || 0x012E when _moreAbove(text, index):
            return '${String.fromCharCode(cp).toLowerCase()}\u0307';
          case 0x00CC:
            return 'i\u0307\u0300';
          case 0x00CD:
            return 'i\u0307\u0301';
          case 0x0128:
            return 'i\u0307\u0303';
        }
      case _Rules.root:
        break;
    }
    // Σ always maps here: on the web, String.toLowerCase applies its own
    // Final_Sigma to the run it sees, which may be shorter than the text.
    if (cp == _capitalSigma) {
      return _isFinalSigma(text, index) ? '\u03C2' : '\u03C3';
    }
    if (cp == _capitalIWithDot) return 'i\u0307';
    final delta = _deltaFor(cp);
    if (delta == null) return null;
    final mapped = delta.lowerOf(cp);
    return mapped == cp ? null : String.fromCharCode(mapped);
  }

  /// The title-case mapping of [cp].
  String _title(int cp) {
    if (_rules == _Rules.turkic && cp == _smallI) return '\u0130';
    final full = _fullMappings[cp];
    if (full != null) return full.title;
    // The four Latin digraphs have a title-case form of their own.
    switch (cp) {
      case 0x01C4 || 0x01C5 || 0x01C6:
        return '\u01C5';
      case 0x01C7 || 0x01C8 || 0x01C9:
        return '\u01C8';
      case 0x01CA || 0x01CB || 0x01CC:
        return '\u01CB';
      case 0x01F1 || 0x01F2 || 0x01F3:
        return '\u01F2';
    }
    // Georgian Mkhedruli letters upper-case to Mtavruli but title-case to
    // themselves (UnicodeData.txt since Unicode 11.0).
    if ((cp >= 0x10D0 && cp <= 0x10FA) || (cp >= 0x10FD && cp <= 0x10FF)) {
      return String.fromCharCode(cp);
    }
    final delta = _deltaFor(cp);
    if (delta != null) return String.fromCharCode(delta.upperOf(cp));
    return String.fromCharCode(cp).toUpperCase();
  }
}

/// The three rule sets of SpecialCasing.txt that the UI needs.
enum _Rules { root, turkic, lithuanian }

const int _capitalI = 0x0049;
const int _smallI = 0x0069;
const int _capitalIWithDot = 0x0130;
const int _combiningDotAbove = 0x0307;
const int _capitalSigma = 0x03A3;

/// Canonical combining class 230 (Above). [_combiningClass] reports every
/// other nonzero class as 1, which is all the context rules need.
const int _cccAbove = 230;

/// Maps [text] code point by code point: [special] returns the mapping of a
/// code point that needs one, or null; runs of the other code points go
/// through [plain] in one call.
String _mapText(
  String text,
  String? Function(int index, int cp) special,
  String Function(String run) plain,
) {
  StringBuffer? out;
  var runStart = 0;
  var index = 0;
  while (index < text.length) {
    final cp = _codePointAt(text, index);
    final next = index + _width(cp);
    final mapped = special(index, cp);
    if (mapped != null) {
      (out ??= StringBuffer())
        ..write(plain(text.substring(runStart, index)))
        ..write(mapped);
      runStart = next;
    }
    index = next;
  }
  if (out == null) return plain(text);
  out.write(plain(text.substring(runStart)));
  return out.toString();
}

bool _isAscii(String text) {
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) >= 0x80) return false;
  }
  return true;
}

/// The code point that starts at UTF-16 [index] of [text]. A lone surrogate
/// is returned as itself.
int _codePointAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return unit;
}

/// The code point that ends just before UTF-16 [index] of [text].
int _codePointBefore(String text, int index) {
  final unit = text.codeUnitAt(index - 1);
  if (unit >= 0xDC00 && unit <= 0xDFFF && index >= 2) {
    final high = text.codeUnitAt(index - 2);
    if (high >= 0xD800 && high <= 0xDBFF) {
      return 0x10000 + ((high - 0xD800) << 10) + (unit - 0xDC00);
    }
  }
  return unit;
}

/// The number of UTF-16 code units of [cp].
int _width(int cp) => cp > 0xFFFF ? 2 : 1;

/// After_Soft_Dotted: a soft-dotted letter comes before the code point at
/// [index], with no character of combining class 0 or 230 between them.
bool _afterSoftDotted(String text, int index) {
  var at = index;
  while (at > 0) {
    final cp = _codePointBefore(text, at);
    if (_isSoftDotted(cp)) return true;
    final ccc = _combiningClass(cp);
    if (ccc == 0 || ccc == _cccAbove) return false;
    at -= _width(cp);
  }
  return false;
}

/// After_I: a capital I comes before the code point at [index], with no
/// character of combining class 0 or 230 between them.
bool _afterCapitalI(String text, int index) {
  var at = index;
  while (at > 0) {
    final cp = _codePointBefore(text, at);
    if (cp == _capitalI) return true;
    final ccc = _combiningClass(cp);
    if (ccc == 0 || ccc == _cccAbove) return false;
    at -= _width(cp);
  }
  return false;
}

/// Before_Dot: U+0307 follows the code point at [index], with only
/// characters of combining classes other than 0 and 230 between them.
bool _beforeDotAbove(String text, int index) {
  var at = index + _width(_codePointAt(text, index));
  while (at < text.length) {
    final cp = _codePointAt(text, at);
    if (cp == _combiningDotAbove) return true;
    final ccc = _combiningClass(cp);
    if (ccc == 0 || ccc == _cccAbove) return false;
    at += _width(cp);
  }
  return false;
}

/// More_Above: a character of combining class 230 follows the code point at
/// [index], with only characters of other nonzero classes between them.
bool _moreAbove(String text, int index) {
  var at = index + _width(_codePointAt(text, index));
  while (at < text.length) {
    final cp = _codePointAt(text, at);
    final ccc = _combiningClass(cp);
    if (ccc == _cccAbove) return true;
    if (ccc == 0) return false;
    at += _width(cp);
  }
  return false;
}

/// Final_Sigma: a cased letter, then any case-ignorable characters, come
/// before [index]; no case-ignorable characters and then a cased letter
/// come after it.
bool _isFinalSigma(String text, int index) {
  var at = index;
  var casedBefore = false;
  while (at > 0) {
    final cp = _codePointBefore(text, at);
    at -= _width(cp);
    if (_inRanges(_caseIgnorable, cp)) continue;
    casedBefore = _inRanges(_cased, cp);
    break;
  }
  if (!casedBefore) return false;
  at = index + _width(_codePointAt(text, index));
  while (at < text.length) {
    final cp = _codePointAt(text, at);
    at += _width(cp);
    if (_inRanges(_caseIgnorable, cp)) continue;
    return !_inRanges(_cased, cp);
  }
  return true;
}

bool _isSoftDotted(int cp) => _inRanges(_softDotted, cp);

/// 0, [_cccAbove] or 1 (any other nonzero class), from [_marksAbove] and
/// [_marksOther].
int _combiningClass(int cp) {
  if (cp < 0x0300) return 0;
  if (_inRanges(_marksAbove, cp)) return _cccAbove;
  return _inRanges(_marksOther, cp) ? 1 : 0;
}

bool _skipsBeforeFirstLetter(int cp) {
  if (cp < 0x80) {
    final isDigit = cp >= 0x30 && cp <= 0x39;
    final isLetter = (cp | 0x20) >= 0x61 && (cp | 0x20) <= 0x7A;
    return !isDigit && !isLetter;
  }
  if (cp >= 0xA0 && cp <= 0xBF) return cp != 0xAA && cp != 0xB5 && cp != 0xBA;
  return (cp >= 0x2000 && cp <= 0x206F) || (cp >= 0x3000 && cp <= 0x303F);
}

/// Whether [cp] lies in the inversion list [ranges]: sorted boundaries, each
/// range from an even entry (inclusive) to the next entry (exclusive).
bool _inRanges(List<int> ranges, int cp) {
  var low = 0;
  var high = ranges.length;
  while (low < high) {
    final middle = (low + high) >> 1;
    if (ranges[middle] <= cp) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low.isOdd;
}

_Delta? _deltaFor(int cp) {
  if (cp < _deltas.first.start || cp > _deltas.last.end) return null;
  var low = 0;
  var high = _deltas.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    final delta = _deltas[middle];
    if (cp < delta.start) {
      high = middle - 1;
    } else if (cp > delta.end) {
      low = middle + 1;
    } else {
      return delta;
    }
  }
  return null;
}

/// An unconditional full mapping of SpecialCasing.txt.
final class _Full {
  const new(this.upper, this.title);

  final String upper;
  final String title;
}

/// A simple case mapping that the Dart VM lacks, for the code points from
/// [start] to [end] (inclusive): each maps to itself plus [upper] or
/// [lower], or, when [isAlternating], upper and lower case alternate from
/// an upper-case [start].
final class _Delta {
  const new(this.start, this.end, {this.upper = 0, this.lower = 0})
    : isAlternating = false;

  const new alternating(this.start, this.end)
    : upper = 0,
      lower = 0,
      isAlternating = true;

  final int start;
  final int end;
  final int upper;
  final int lower;
  final bool isAlternating;

  int upperOf(int cp) =>
      isAlternating ? ((cp - start).isOdd ? cp - 1 : cp) : cp + upper;

  int lowerOf(int cp) =>
      isAlternating ? ((cp - start).isEven ? cp + 1 : cp) : cp + lower;
}

// dart format off
// The tables below come from the Unicode Character Database 15.0.0
// (SpecialCasing.txt, UnicodeData.txt, PropList.txt and
// DerivedCoreProperties.txt), read with Perl 5.38's Unicode::UCD; the Dart
// VM's mappings were dumped from Dart 3.13.5. Unicode data is covered by
// the Unicode License v3 (https://www.unicode.org/license.txt), a
// permissive licence. `dart format off` keeps the inversion lists in rows.
// The generator is not in the repository yet (BACKLOG.md, "Generator for
// the casing tables"); do not edit the tables by hand. Until it lands,
// casing_test.dart (the SpecialCasing lines) and casing_icu_test.dart (ICU
// results) are the check on them.

/// The unconditional entries of SpecialCasing-15.0.0.txt: code point →
/// full upper-case and title-case mapping. Their lower-case mappings are
/// the simple ones, except U+0130, which [LocaleCasing.lower] handles.
const Map<int, _Full> _fullMappings = {
  0x00DF: _Full('SS', 'Ss'),
  0x0130: _Full('\u0130', '\u0130'),
  0x0149: _Full('\u02BCN', '\u02BCN'),
  0x01F0: _Full('J\u030C', 'J\u030C'),
  0x0390: _Full('\u0399\u0308\u0301', '\u0399\u0308\u0301'),
  0x03B0: _Full('\u03A5\u0308\u0301', '\u03A5\u0308\u0301'),
  0x0587: _Full('\u0535\u0552', '\u0535\u0582'),
  0x1E96: _Full('H\u0331', 'H\u0331'),
  0x1E97: _Full('T\u0308', 'T\u0308'),
  0x1E98: _Full('W\u030A', 'W\u030A'),
  0x1E99: _Full('Y\u030A', 'Y\u030A'),
  0x1E9A: _Full('A\u02BE', 'A\u02BE'),
  0x1F50: _Full('\u03A5\u0313', '\u03A5\u0313'),
  0x1F52: _Full('\u03A5\u0313\u0300', '\u03A5\u0313\u0300'),
  0x1F54: _Full('\u03A5\u0313\u0301', '\u03A5\u0313\u0301'),
  0x1F56: _Full('\u03A5\u0313\u0342', '\u03A5\u0313\u0342'),
  0x1F80: _Full('\u1F08\u0399', '\u1F88'),
  0x1F81: _Full('\u1F09\u0399', '\u1F89'),
  0x1F82: _Full('\u1F0A\u0399', '\u1F8A'),
  0x1F83: _Full('\u1F0B\u0399', '\u1F8B'),
  0x1F84: _Full('\u1F0C\u0399', '\u1F8C'),
  0x1F85: _Full('\u1F0D\u0399', '\u1F8D'),
  0x1F86: _Full('\u1F0E\u0399', '\u1F8E'),
  0x1F87: _Full('\u1F0F\u0399', '\u1F8F'),
  0x1F88: _Full('\u1F08\u0399', '\u1F88'),
  0x1F89: _Full('\u1F09\u0399', '\u1F89'),
  0x1F8A: _Full('\u1F0A\u0399', '\u1F8A'),
  0x1F8B: _Full('\u1F0B\u0399', '\u1F8B'),
  0x1F8C: _Full('\u1F0C\u0399', '\u1F8C'),
  0x1F8D: _Full('\u1F0D\u0399', '\u1F8D'),
  0x1F8E: _Full('\u1F0E\u0399', '\u1F8E'),
  0x1F8F: _Full('\u1F0F\u0399', '\u1F8F'),
  0x1F90: _Full('\u1F28\u0399', '\u1F98'),
  0x1F91: _Full('\u1F29\u0399', '\u1F99'),
  0x1F92: _Full('\u1F2A\u0399', '\u1F9A'),
  0x1F93: _Full('\u1F2B\u0399', '\u1F9B'),
  0x1F94: _Full('\u1F2C\u0399', '\u1F9C'),
  0x1F95: _Full('\u1F2D\u0399', '\u1F9D'),
  0x1F96: _Full('\u1F2E\u0399', '\u1F9E'),
  0x1F97: _Full('\u1F2F\u0399', '\u1F9F'),
  0x1F98: _Full('\u1F28\u0399', '\u1F98'),
  0x1F99: _Full('\u1F29\u0399', '\u1F99'),
  0x1F9A: _Full('\u1F2A\u0399', '\u1F9A'),
  0x1F9B: _Full('\u1F2B\u0399', '\u1F9B'),
  0x1F9C: _Full('\u1F2C\u0399', '\u1F9C'),
  0x1F9D: _Full('\u1F2D\u0399', '\u1F9D'),
  0x1F9E: _Full('\u1F2E\u0399', '\u1F9E'),
  0x1F9F: _Full('\u1F2F\u0399', '\u1F9F'),
  0x1FA0: _Full('\u1F68\u0399', '\u1FA8'),
  0x1FA1: _Full('\u1F69\u0399', '\u1FA9'),
  0x1FA2: _Full('\u1F6A\u0399', '\u1FAA'),
  0x1FA3: _Full('\u1F6B\u0399', '\u1FAB'),
  0x1FA4: _Full('\u1F6C\u0399', '\u1FAC'),
  0x1FA5: _Full('\u1F6D\u0399', '\u1FAD'),
  0x1FA6: _Full('\u1F6E\u0399', '\u1FAE'),
  0x1FA7: _Full('\u1F6F\u0399', '\u1FAF'),
  0x1FA8: _Full('\u1F68\u0399', '\u1FA8'),
  0x1FA9: _Full('\u1F69\u0399', '\u1FA9'),
  0x1FAA: _Full('\u1F6A\u0399', '\u1FAA'),
  0x1FAB: _Full('\u1F6B\u0399', '\u1FAB'),
  0x1FAC: _Full('\u1F6C\u0399', '\u1FAC'),
  0x1FAD: _Full('\u1F6D\u0399', '\u1FAD'),
  0x1FAE: _Full('\u1F6E\u0399', '\u1FAE'),
  0x1FAF: _Full('\u1F6F\u0399', '\u1FAF'),
  0x1FB2: _Full('\u1FBA\u0399', '\u1FBA\u0345'),
  0x1FB3: _Full('\u0391\u0399', '\u1FBC'),
  0x1FB4: _Full('\u0386\u0399', '\u0386\u0345'),
  0x1FB6: _Full('\u0391\u0342', '\u0391\u0342'),
  0x1FB7: _Full('\u0391\u0342\u0399', '\u0391\u0342\u0345'),
  0x1FBC: _Full('\u0391\u0399', '\u1FBC'),
  0x1FC2: _Full('\u1FCA\u0399', '\u1FCA\u0345'),
  0x1FC3: _Full('\u0397\u0399', '\u1FCC'),
  0x1FC4: _Full('\u0389\u0399', '\u0389\u0345'),
  0x1FC6: _Full('\u0397\u0342', '\u0397\u0342'),
  0x1FC7: _Full('\u0397\u0342\u0399', '\u0397\u0342\u0345'),
  0x1FCC: _Full('\u0397\u0399', '\u1FCC'),
  0x1FD2: _Full('\u0399\u0308\u0300', '\u0399\u0308\u0300'),
  0x1FD3: _Full('\u0399\u0308\u0301', '\u0399\u0308\u0301'),
  0x1FD6: _Full('\u0399\u0342', '\u0399\u0342'),
  0x1FD7: _Full('\u0399\u0308\u0342', '\u0399\u0308\u0342'),
  0x1FE2: _Full('\u03A5\u0308\u0300', '\u03A5\u0308\u0300'),
  0x1FE3: _Full('\u03A5\u0308\u0301', '\u03A5\u0308\u0301'),
  0x1FE4: _Full('\u03A1\u0313', '\u03A1\u0313'),
  0x1FE6: _Full('\u03A5\u0342', '\u03A5\u0342'),
  0x1FE7: _Full('\u03A5\u0308\u0342', '\u03A5\u0308\u0342'),
  0x1FF2: _Full('\u1FFA\u0399', '\u1FFA\u0345'),
  0x1FF3: _Full('\u03A9\u0399', '\u1FFC'),
  0x1FF4: _Full('\u038F\u0399', '\u038F\u0345'),
  0x1FF6: _Full('\u03A9\u0342', '\u03A9\u0342'),
  0x1FF7: _Full('\u03A9\u0342\u0399', '\u03A9\u0342\u0345'),
  0x1FFC: _Full('\u03A9\u0399', '\u1FFC'),
  0xFB00: _Full('FF', 'Ff'),
  0xFB01: _Full('FI', 'Fi'),
  0xFB02: _Full('FL', 'Fl'),
  0xFB03: _Full('FFI', 'Ffi'),
  0xFB04: _Full('FFL', 'Ffl'),
  0xFB05: _Full('ST', 'St'),
  0xFB06: _Full('ST', 'St'),
  0xFB13: _Full('\u0544\u0546', '\u0544\u0576'),
  0xFB14: _Full('\u0544\u0535', '\u0544\u0565'),
  0xFB15: _Full('\u0544\u053B', '\u0544\u056B'),
  0xFB16: _Full('\u054E\u0546', '\u054E\u0576'),
  0xFB17: _Full('\u0544\u053D', '\u0544\u056D'),
};

/// Simple case mappings of UnicodeData-15.0.0.txt that the Dart VM
/// (Dart 3.13.5) does not apply: 829 code points, all unmapped by the VM.
/// Sorted by [_Delta.start].
const List<_Delta> _deltas = [
  _Delta(0x023F, 0x0240, upper: 10815),
  _Delta(0x0252, 0x0252, upper: 10782),
  _Delta(0x025C, 0x025C, upper: 42319),
  _Delta(0x0261, 0x0261, upper: 42315),
  _Delta(0x0265, 0x0265, upper: 42280),
  _Delta(0x0266, 0x0266, upper: 42308),
  _Delta(0x026A, 0x026A, upper: 42308),
  _Delta(0x026C, 0x026C, upper: 42305),
  _Delta(0x0282, 0x0282, upper: 42307),
  _Delta(0x0287, 0x0287, upper: 42282),
  _Delta(0x029D, 0x029D, upper: 42261),
  _Delta(0x029E, 0x029E, upper: 42258),
  _Delta(0x037F, 0x037F, lower: 116),
  _Delta(0x03F3, 0x03F3, upper: -116),
  _Delta.alternating(0x0524, 0x052F),
  _Delta(0x10C7, 0x10C7, lower: 7264),
  _Delta(0x10CD, 0x10CD, lower: 7264),
  _Delta(0x10D0, 0x10FA, upper: 3008),
  _Delta(0x10FD, 0x10FF, upper: 3008),
  _Delta(0x13A0, 0x13EF, lower: 38864),
  _Delta(0x13F0, 0x13F5, lower: 8),
  _Delta(0x13F8, 0x13FD, upper: -8),
  _Delta(0x1C80, 0x1C80, upper: -6254),
  _Delta(0x1C81, 0x1C81, upper: -6253),
  _Delta(0x1C82, 0x1C82, upper: -6244),
  _Delta(0x1C83, 0x1C84, upper: -6242),
  _Delta(0x1C85, 0x1C85, upper: -6243),
  _Delta(0x1C86, 0x1C86, upper: -6236),
  _Delta(0x1C87, 0x1C87, upper: -6181),
  _Delta(0x1C88, 0x1C88, upper: 35266),
  _Delta(0x1C90, 0x1CBA, lower: -3008),
  _Delta(0x1CBD, 0x1CBF, lower: -3008),
  _Delta(0x1D8E, 0x1D8E, upper: 35384),
  _Delta(0x2C2F, 0x2C2F, lower: 48),
  _Delta(0x2C5F, 0x2C5F, upper: -48),
  _Delta(0x2C70, 0x2C70, lower: -10782),
  _Delta(0x2C7E, 0x2C7F, lower: -10815),
  _Delta.alternating(0x2CEB, 0x2CEE),
  _Delta.alternating(0x2CF2, 0x2CF3),
  _Delta(0x2D27, 0x2D27, upper: -7264),
  _Delta(0x2D2D, 0x2D2D, upper: -7264),
  _Delta.alternating(0xA660, 0xA661),
  _Delta.alternating(0xA698, 0xA69B),
  _Delta(0xA78D, 0xA78D, lower: -42280),
  _Delta.alternating(0xA790, 0xA793),
  _Delta(0xA794, 0xA794, upper: 48),
  _Delta.alternating(0xA796, 0xA7A9),
  _Delta(0xA7AA, 0xA7AA, lower: -42308),
  _Delta(0xA7AB, 0xA7AB, lower: -42319),
  _Delta(0xA7AC, 0xA7AC, lower: -42315),
  _Delta(0xA7AD, 0xA7AD, lower: -42305),
  _Delta(0xA7AE, 0xA7AE, lower: -42308),
  _Delta(0xA7B0, 0xA7B0, lower: -42258),
  _Delta(0xA7B1, 0xA7B1, lower: -42282),
  _Delta(0xA7B2, 0xA7B2, lower: -42261),
  _Delta(0xA7B3, 0xA7B3, lower: 928),
  _Delta.alternating(0xA7B4, 0xA7C3),
  _Delta(0xA7C4, 0xA7C4, lower: -48),
  _Delta(0xA7C5, 0xA7C5, lower: -42307),
  _Delta(0xA7C6, 0xA7C6, lower: -35384),
  _Delta.alternating(0xA7C7, 0xA7CA),
  _Delta.alternating(0xA7D0, 0xA7D1),
  _Delta.alternating(0xA7D6, 0xA7D9),
  _Delta.alternating(0xA7F5, 0xA7F6),
  _Delta(0xAB53, 0xAB53, upper: -928),
  _Delta(0xAB70, 0xABBF, upper: -38864),
  _Delta(0x104B0, 0x104D3, lower: 40),
  _Delta(0x104D8, 0x104FB, upper: -40),
  _Delta(0x10570, 0x1057A, lower: 39),
  _Delta(0x1057C, 0x1058A, lower: 39),
  _Delta(0x1058C, 0x10592, lower: 39),
  _Delta(0x10594, 0x10595, lower: 39),
  _Delta(0x10597, 0x105A1, upper: -39),
  _Delta(0x105A3, 0x105B1, upper: -39),
  _Delta(0x105B3, 0x105B9, upper: -39),
  _Delta(0x105BB, 0x105BC, upper: -39),
  _Delta(0x10C80, 0x10CB2, lower: 64),
  _Delta(0x10CC0, 0x10CF2, upper: -64),
  _Delta(0x118A0, 0x118BF, lower: 32),
  _Delta(0x118C0, 0x118DF, upper: -32),
  _Delta(0x16E40, 0x16E5F, lower: 32),
  _Delta(0x16E60, 0x16E7F, upper: -32),
  _Delta(0x1E900, 0x1E921, lower: 34),
  _Delta(0x1E922, 0x1E943, upper: -34),
];

/// Soft_Dotted (PropList-15.0.0.txt), complete.
const List<int> _softDotted = [
  0x69, 0x6B, 0x12F, 0x130, 0x249, 0x24A, 0x268, 0x269,
  0x29D, 0x29E, 0x2B2, 0x2B3, 0x3F3, 0x3F4, 0x456, 0x457,
  0x458, 0x459, 0x1D62, 0x1D63, 0x1D96, 0x1D97, 0x1DA4, 0x1DA5,
  0x1DA8, 0x1DA9, 0x1E2D, 0x1E2E, 0x1ECB, 0x1ECC, 0x2071, 0x2072,
  0x2148, 0x214A, 0x2C7C, 0x2C7D, 0x1D422, 0x1D424, 0x1D456, 0x1D458,
  0x1D48A, 0x1D48C, 0x1D4BE, 0x1D4C0, 0x1D4F2, 0x1D4F4, 0x1D526, 0x1D528,
  0x1D55A, 0x1D55C, 0x1D58E, 0x1D590, 0x1D5C2, 0x1D5C4, 0x1D5F6, 0x1D5F8,
  0x1D62A, 0x1D62C, 0x1D65E, 0x1D660, 0x1D692, 0x1D694, 0x1DF1A, 0x1DF1B,
  0x1E04C, 0x1E04E, 0x1E068, 0x1E069,
];

/// Cased (DerivedCoreProperties-15.0.0.txt), complete.
const List<int> _cased = [
  0x41, 0x5B, 0x61, 0x7B, 0xAA, 0xAB, 0xB5, 0xB6,
  0xBA, 0xBB, 0xC0, 0xD7, 0xD8, 0xF7, 0xF8, 0x1BB,
  0x1BC, 0x1C0, 0x1C4, 0x294, 0x295, 0x2B9, 0x2C0, 0x2C2,
  0x2E0, 0x2E5, 0x345, 0x346, 0x370, 0x374, 0x376, 0x378,
  0x37A, 0x37E, 0x37F, 0x380, 0x386, 0x387, 0x388, 0x38B,
  0x38C, 0x38D, 0x38E, 0x3A2, 0x3A3, 0x3F6, 0x3F7, 0x482,
  0x48A, 0x530, 0x531, 0x557, 0x560, 0x589, 0x10A0, 0x10C6,
  0x10C7, 0x10C8, 0x10CD, 0x10CE, 0x10D0, 0x10FB, 0x10FC, 0x1100,
  0x13A0, 0x13F6, 0x13F8, 0x13FE, 0x1C80, 0x1C89, 0x1C90, 0x1CBB,
  0x1CBD, 0x1CC0, 0x1D00, 0x1DC0, 0x1E00, 0x1F16, 0x1F18, 0x1F1E,
  0x1F20, 0x1F46, 0x1F48, 0x1F4E, 0x1F50, 0x1F58, 0x1F59, 0x1F5A,
  0x1F5B, 0x1F5C, 0x1F5D, 0x1F5E, 0x1F5F, 0x1F7E, 0x1F80, 0x1FB5,
  0x1FB6, 0x1FBD, 0x1FBE, 0x1FBF, 0x1FC2, 0x1FC5, 0x1FC6, 0x1FCD,
  0x1FD0, 0x1FD4, 0x1FD6, 0x1FDC, 0x1FE0, 0x1FED, 0x1FF2, 0x1FF5,
  0x1FF6, 0x1FFD, 0x2071, 0x2072, 0x207F, 0x2080, 0x2090, 0x209D,
  0x2102, 0x2103, 0x2107, 0x2108, 0x210A, 0x2114, 0x2115, 0x2116,
  0x2119, 0x211E, 0x2124, 0x2125, 0x2126, 0x2127, 0x2128, 0x2129,
  0x212A, 0x212E, 0x212F, 0x2135, 0x2139, 0x213A, 0x213C, 0x2140,
  0x2145, 0x214A, 0x214E, 0x214F, 0x2160, 0x2180, 0x2183, 0x2185,
  0x24B6, 0x24EA, 0x2C00, 0x2CE5, 0x2CEB, 0x2CEF, 0x2CF2, 0x2CF4,
  0x2D00, 0x2D26, 0x2D27, 0x2D28, 0x2D2D, 0x2D2E, 0xA640, 0xA66E,
  0xA680, 0xA69E, 0xA722, 0xA788, 0xA78B, 0xA78F, 0xA790, 0xA7CB,
  0xA7D0, 0xA7D2, 0xA7D3, 0xA7D4, 0xA7D5, 0xA7DA, 0xA7F2, 0xA7F7,
  0xA7F8, 0xA7FB, 0xAB30, 0xAB5B, 0xAB5C, 0xAB6A, 0xAB70, 0xABC0,
  0xFB00, 0xFB07, 0xFB13, 0xFB18, 0xFF21, 0xFF3B, 0xFF41, 0xFF5B,
  0x10400, 0x10450, 0x104B0, 0x104D4, 0x104D8, 0x104FC, 0x10570, 0x1057B,
  0x1057C, 0x1058B, 0x1058C, 0x10593, 0x10594, 0x10596, 0x10597, 0x105A2,
  0x105A3, 0x105B2, 0x105B3, 0x105BA, 0x105BB, 0x105BD, 0x10780, 0x10781,
  0x10783, 0x10786, 0x10787, 0x107B1, 0x107B2, 0x107BB, 0x10C80, 0x10CB3,
  0x10CC0, 0x10CF3, 0x118A0, 0x118E0, 0x16E40, 0x16E80, 0x1D400, 0x1D455,
  0x1D456, 0x1D49D, 0x1D49E, 0x1D4A0, 0x1D4A2, 0x1D4A3, 0x1D4A5, 0x1D4A7,
  0x1D4A9, 0x1D4AD, 0x1D4AE, 0x1D4BA, 0x1D4BB, 0x1D4BC, 0x1D4BD, 0x1D4C4,
  0x1D4C5, 0x1D506, 0x1D507, 0x1D50B, 0x1D50D, 0x1D515, 0x1D516, 0x1D51D,
  0x1D51E, 0x1D53A, 0x1D53B, 0x1D53F, 0x1D540, 0x1D545, 0x1D546, 0x1D547,
  0x1D54A, 0x1D551, 0x1D552, 0x1D6A6, 0x1D6A8, 0x1D6C1, 0x1D6C2, 0x1D6DB,
  0x1D6DC, 0x1D6FB, 0x1D6FC, 0x1D715, 0x1D716, 0x1D735, 0x1D736, 0x1D74F,
  0x1D750, 0x1D76F, 0x1D770, 0x1D789, 0x1D78A, 0x1D7A9, 0x1D7AA, 0x1D7C3,
  0x1D7C4, 0x1D7CC, 0x1DF00, 0x1DF0A, 0x1DF0B, 0x1DF1F, 0x1DF25, 0x1DF2B,
  0x1E030, 0x1E06E, 0x1E900, 0x1E944, 0x1F130, 0x1F14A, 0x1F150, 0x1F16A,
  0x1F170, 0x1F18A,
];

/// Case_Ignorable (DerivedCoreProperties-15.0.0.txt) in U+0000 to U+052F,
/// U+1AB0 to U+1AFF, U+1D00 to U+20FF, U+FE00 to U+FE2F and U+FE50 to
/// U+FF6F.
const List<int> _caseIgnorable = [
  0x27, 0x28, 0x2E, 0x2F, 0x3A, 0x3B, 0x5E, 0x5F,
  0x60, 0x61, 0xA8, 0xA9, 0xAD, 0xAE, 0xAF, 0xB0,
  0xB4, 0xB5, 0xB7, 0xB9, 0x2B0, 0x370, 0x374, 0x376,
  0x37A, 0x37B, 0x384, 0x386, 0x387, 0x388, 0x483, 0x48A,
  0x1AB0, 0x1ACF, 0x1D2C, 0x1D6B, 0x1D78, 0x1D79, 0x1D9B, 0x1E00,
  0x1FBD, 0x1FBE, 0x1FBF, 0x1FC2, 0x1FCD, 0x1FD0, 0x1FDD, 0x1FE0,
  0x1FED, 0x1FF0, 0x1FFD, 0x1FFF, 0x200B, 0x2010, 0x2018, 0x201A,
  0x2024, 0x2025, 0x2027, 0x2028, 0x202A, 0x202F, 0x2060, 0x2065,
  0x2066, 0x2070, 0x2071, 0x2072, 0x207F, 0x2080, 0x2090, 0x209D,
  0x20D0, 0x20F1, 0xFE00, 0xFE10, 0xFE13, 0xFE14, 0xFE20, 0xFE30,
  0xFE52, 0xFE53, 0xFE55, 0xFE56, 0xFEFF, 0xFF00, 0xFF07, 0xFF08,
  0xFF0E, 0xFF0F, 0xFF1A, 0xFF1B, 0xFF3E, 0xFF3F, 0xFF40, 0xFF41,
];

/// Canonical combining class 230 (UnicodeData-15.0.0.txt) in the mark
/// blocks U+0300 to U+036F, U+0483 to U+0489, U+1AB0 to U+1AFF, U+1DC0 to
/// U+1DFF, U+20D0 to U+20FF and U+FE20 to U+FE2F.
const List<int> _marksAbove = [
  0x300, 0x315, 0x33D, 0x345, 0x346, 0x347, 0x34A, 0x34D,
  0x350, 0x353, 0x357, 0x358, 0x35B, 0x35C, 0x363, 0x370,
  0x483, 0x488, 0x1AB0, 0x1AB5, 0x1ABB, 0x1ABD, 0x1AC1, 0x1AC3,
  0x1AC5, 0x1ACA, 0x1ACB, 0x1ACF, 0x1DC0, 0x1DC2, 0x1DC3, 0x1DCA,
  0x1DCB, 0x1DCD, 0x1DD1, 0x1DF6, 0x1DFB, 0x1DFC, 0x1DFE, 0x1DFF,
  0x20D0, 0x20D2, 0x20D4, 0x20D8, 0x20DB, 0x20DD, 0x20E1, 0x20E2,
  0x20E7, 0x20E8, 0x20E9, 0x20EA, 0x20F0, 0x20F1, 0xFE20, 0xFE27,
  0xFE2E, 0xFE30,
];

/// Every other nonzero canonical combining class in the same mark blocks.
const List<int> _marksOther = [
  0x315, 0x33D, 0x345, 0x346, 0x347, 0x34A, 0x34D, 0x34F,
  0x353, 0x357, 0x358, 0x35B, 0x35C, 0x363, 0x1AB5, 0x1ABB,
  0x1ABD, 0x1ABE, 0x1ABF, 0x1AC1, 0x1AC3, 0x1AC5, 0x1ACA, 0x1ACB,
  0x1DC2, 0x1DC3, 0x1DCA, 0x1DCB, 0x1DCD, 0x1DD1, 0x1DF6, 0x1DFB,
  0x1DFC, 0x1DFE, 0x1DFF, 0x1E00, 0x20D2, 0x20D4, 0x20D8, 0x20DB,
  0x20E5, 0x20E7, 0x20E8, 0x20E9, 0x20EA, 0x20F0, 0xFE27, 0xFE2E,
];
// dart format on
