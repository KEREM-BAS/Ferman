import 'dart:convert';
import 'dart:ui' as ui;

import 'package:ferman/design/components/annotations/stamp.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The languages a stamp's capitals can follow (a4-3b's `capLangs`).
enum StampLanguage {
  /// Turkish: i becomes İ.
  turkish(Locale('tr')),

  /// English.
  english(Locale('en')),

  /// German.
  german(Locale('de'));

  new(this.locale);

  /// The language of the stamp's text.
  final Locale locale;
}

/// One stamp of the library (a4-3): what it reads and what its second line is
/// filled with at placement (M4 plan, decision 10), not a live field.
@immutable
final class StampDesign {
  /// A stamp reading [label].
  const new({
    required this.label,
    required this.tone,
    this.language = StampLanguage.english,
    this.name,
    this.withName = false,
    this.withDate = false,
    this.withTime = false,
    this.pdfName,
  });

  /// The longest label a stamp takes, in code units.
  static const int longestLabel = 64;

  /// The longest name a stamp takes, in code units.
  static const int longestName = 128;

  /// The largest stamp file read.
  static const int largestFile = 16 * 1024;

  /// A stamp file's extension.
  static const String fileExtension = 'fermanstamp';

  static const String _fileMark = 'fermanStamp';

  /// Reads a stamp from its JSON form; null for anything not a valid stamp.
  /// A stamp comes from settings or a file someone sent, so nothing is trusted.
  static StampDesign? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final label = json['label'];
    final name = json['name'];
    final tone = StampTone.values.asNameMap()[json['tone']];
    final language = StampLanguage.values.asNameMap()[json['language']];
    if (label is! String || label.trim().isEmpty) return null;
    if (label.length > longestLabel || tone == null || language == null) {
      return null;
    }
    if (name != null && (name is! String || name.length > longestName)) {
      return null;
    }
    return StampDesign(
      label: label,
      tone: tone,
      language: language,
      name: name as String?,
      withName: json['withName'] == true,
      withDate: json['withDate'] == true,
      withTime: json['withTime'] == true,
    );
  }

  /// Reads a stamp file; null for anything else.
  static StampDesign? fromFile(Uint8List bytes) {
    if (bytes.length > largestFile) return null;
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, Object?> || json[_fileMark] != 1) return null;
      return fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// The text, before its capitals.
  final String label;

  /// The ink.
  final StampTone tone;

  /// The language of [label].
  final StampLanguage language;

  /// The name a custom stamp was saved with; null takes your name.
  final String? name;

  /// The second line starts with the name.
  final bool withName;

  /// The second line has the date.
  final bool withDate;

  /// The second line has the time.
  final bool withTime;

  /// The standard `/Name` of a standard stamp.
  final String? pdfName;

  /// [label] in capitals, by [language]'s rules.
  String get capitals => LocaleCasing.forLocale(language.locale).upper(label);

  /// The second line at [now] in the region's format (G154), or null without
  /// one: "Av. Deniz Aksoy · 13.10.2026".
  String? metaAt(DateTime now, RegionFormat format, String yourName) {
    final person = withName ? (name ?? yourName).trim() : '';
    final when = [
      if (withDate) format.date(now),
      if (withTime) format.time(now),
    ].join(' ');
    final parts = [person, when].where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The JSON form, as settings keep it.
  Map<String, Object?> toJson() => {
    'label': label,
    'tone': tone.name,
    'language': language.name,
    'name': ?name,
    'withName': withName,
    'withDate': withDate,
    'withTime': withTime,
  };

  /// What a stamp file holds, to share with colleagues (a4-3b, G153).
  Uint8List toFile() => utf8.encode(jsonEncode({_fileMark: 1, ...toJson()}));

  @override
  bool operator ==(Object other) =>
      other is StampDesign &&
      other.label == label &&
      other.tone == tone &&
      other.language == language &&
      other.name == name &&
      other.withName == withName &&
      other.withDate == withDate &&
      other.withTime == withTime;

  @override
  int get hashCode =>
      Object.hash(label, tone, language, name, withName, withDate, withTime);
}

/// The STANDARD group of a4-3. The labels are the stamps' own text, not UI
/// copy, and `pdfName` their name in the PDF standard.
const List<StampDesign> standardStamps = [
  StampDesign(label: 'Approved', tone: StampTone.green, pdfName: 'Approved'),
  StampDesign(label: 'Draft', tone: StampTone.neutral, pdfName: 'Draft'),
  StampDesign(
    label: 'Confidential',
    tone: StampTone.seal,
    pdfName: 'Confidential',
  ),
  StampDesign(label: 'Final', tone: StampTone.ink, pdfName: 'Final'),
  StampDesign(
    label: 'Not approved',
    tone: StampTone.seal,
    pdfName: 'NotApproved',
  ),
];

/// The TÜRKÇE group of a4-3.
const List<StampDesign> turkishStamps = [
  StampDesign(
    label: 'Onaylandı',
    tone: StampTone.seal,
    language: StampLanguage.turkish,
  ),
  StampDesign(
    label: 'Taslak',
    tone: StampTone.neutral,
    language: StampLanguage.turkish,
  ),
  StampDesign(
    label: 'Gizli',
    tone: StampTone.seal,
    language: StampLanguage.turkish,
  ),
  StampDesign(
    label: 'Aslı gibidir',
    tone: StampTone.ink,
    language: StampLanguage.turkish,
  ),
  StampDesign(
    label: 'Alındı',
    tone: StampTone.green,
    language: StampLanguage.turkish,
  ),
];

/// The WITH NAME AND DATE group of a4-3.
const List<StampDesign> namedStamps = [
  StampDesign(
    label: 'Approved',
    tone: StampTone.green,
    withName: true,
    withDate: true,
    pdfName: 'Approved',
  ),
  StampDesign(
    label: 'Alındı',
    tone: StampTone.ink,
    language: StampLanguage.turkish,
    withDate: true,
    withTime: true,
  ),
];

/// The label's size at 100 %, in points: the boards' 18 px on a page they draw
/// 794 px wide for A4's 595 pt.
const double stampFontSize = 13.5;

/// The turn of a placed stamp (a4-1's `rotation`).
const double stampTilt = -6;

/// The box of a stamp with these lines at [fontSize], in points, before its
/// tilt: `.fm-stamp`'s padding and gap, scaled with the size. [style] is the
/// face the engine's bundled fonts stand for.
Size stampBox(String label, String? meta, double fontSize, TextStyle style) {
  double width(String text, double size, double tracking) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          fontSize: size,
          fontWeight: ui.FontWeight.w600,
          letterSpacing: tracking * size,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  final unit = fontSize / 18;
  final metaSize = fontSize * Stamp.metaFontSize / 18;
  final text = width(label, fontSize, Stamp.tracking);
  final second = meta == null ? 0.0 : width(meta, metaSize, Stamp.metaTracking);
  return Size(
    (text > second ? text : second) + 2 * Stamp.paddingX * unit,
    (Stamp.paddingTop + Stamp.paddingBottom) * unit +
        fontSize +
        (meta == null ? 0 : Stamp.gap * unit + metaSize * Stamp.metaHeight),
  );
}

/// [rect] moved as little as it takes to lie inside a page of [page]; a rect
/// bigger than the page stays centred on it.
Rect keptOnPage(Rect rect, Size page) {
  double along(double start, double length, double whole) =>
      length >= whole ? (whole - length) / 2 : start.clamp(0, whole - length);
  return Rect.fromLTWH(
    along(rect.left, rect.width, page.width),
    along(rect.top, rect.height, page.height),
    rect.width,
    rect.height,
  );
}

/// [color] as an annotation's colour.
AnnotationColor annotationColorOf(ui.Color color) =>
    AnnotationColor(color.r, color.g, color.b);

/// [design] as a new stamp centred on [center] of a page of [page], as near as
/// it stays on the page, [scale] times its usual size. [author] also fills a
/// stamp that takes your name.
NewAnnotation stampAnnotation(
  StampDesign design, {
  required Offset center,
  required Size page,
  required ui.Color ink,
  required String author,
  required DateTime now,
  required RegionFormat format,
  required TextStyle style,
  double scale = 1,
}) {
  final label = design.capitals;
  final meta = design.metaAt(now, format, author);
  final fontSize = stampFontSize * scale;
  final box = stampBox(label, meta, fontSize, style);
  return NewAnnotation(
    kind: AnnotationKind.stamp,
    color: annotationColorOf(ink),
    author: author,
    rect: keptOnPage(
      Rect.fromCenter(center: center, width: box.width, height: box.height),
      page,
    ),
    fontSize: fontSize,
    label: label,
    meta: meta,
    tilt: stampTilt,
    icon: design.pdfName,
  );
}
