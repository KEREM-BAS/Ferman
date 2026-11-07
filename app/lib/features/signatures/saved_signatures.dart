import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/signatures/signature_directory.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_signatures.g.dart';

/// The handwriting styles of a typed signature, in a5-3's order.
const List<String> handwritingFamilies = [
  'Caveat',
  'Homemade Apple',
  'Dancing Script',
];

/// A signature or initials made in a5-3's dialog: placed by a click, and kept
/// on this device as a file of [savedSignaturesProvider] unless it was made
/// with "Save on this device" off ([name] empty). Its ink is never logged
/// (M4 decision 22).
@immutable
final class SavedSignature {
  /// Creates one.
  const new({
    required this.ink,
    required this.color,
    this.name = '',
    this.initials = false,
  });

  /// The file format this app writes.
  static const int version = 1;

  /// The largest image kept: under the engine's 8 MB a file once in Base64.
  static const int largestImage = 6 * 1024 * 1024;

  /// The longest typed name.
  static const int longestText = 256;

  /// The most points of a drawing, all strokes together.
  static const int mostPoints = 100000;

  /// Its file name, empty while it is not saved.
  final String name;

  /// What it is drawn from.
  final SignatureInk ink;

  /// A typed or drawn one's colour.
  final AnnotationColor color;

  /// Initials rather than a signature.
  final bool initials;

  /// A copy saved as [name].
  SavedSignature named(String name) =>
      SavedSignature(ink: ink, color: color, name: name, initials: initials);

  /// What it is written as: JSON, its image in Base64.
  Uint8List toFile() => utf8.encode(
    jsonEncode({
      'fermanSignature': version,
      'initials': initials,
      'color': [color.red, color.green, color.blue],
      ...switch (ink) {
        TypedInk(:final text, :final family) => {
          'typed': {'text': text, 'family': family},
        },
        DrawnInk(:final strokes, :final width) => {
          'drawn': {
            'width': width,
            'strokes': [
              for (final stroke in strokes)
                [
                  for (final point in stroke) ...[point.dx, point.dy],
                ],
            ],
          },
        },
        ImageInk(:final bytes) => {'image': base64Encode(bytes)},
      },
    }),
  );

  /// The file [bytes] named [name], or null when it is not one this app wrote:
  /// the folder is the app's, but its files are read as untrusted.
  static SavedSignature? fromFile(String name, Uint8List bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, Object?> || json['fermanSignature'] != version) {
        return null;
      }
      final initials = json['initials'];
      final color = json['color'];
      if (initials is! bool ||
          color is! List<Object?> ||
          color.length != 3 ||
          !color.every((c) => c is num && c >= 0 && c <= 1)) {
        return null;
      }
      final ink = _ink(json);
      if (ink == null) return null;
      return SavedSignature(
        name: name,
        ink: ink,
        initials: initials,
        color: AnnotationColor(
          (color[0]! as num).toDouble(),
          (color[1]! as num).toDouble(),
          (color[2]! as num).toDouble(),
        ),
      );
    } on FormatException {
      return null;
    }
  }

  static SignatureInk? _ink(Map<String, Object?> json) {
    final typed = json['typed'];
    final drawn = json['drawn'];
    final image = json['image'];
    if (typed is Map<String, Object?>) {
      final text = typed['text'];
      final family = typed['family'];
      if (text is! String ||
          text.trim().isEmpty ||
          text.length > longestText ||
          !handwritingFamilies.contains(family)) {
        return null;
      }
      return TypedInk(text: text, family: family! as String);
    }
    if (drawn is Map<String, Object?>) {
      final width = drawn['width'];
      final strokes = drawn['strokes'];
      if (width is! num || !(width > 0 && width <= 100) || strokes is! List) {
        return null;
      }
      final parsed = <List<Offset>>[];
      var points = 0;
      for (final stroke in strokes) {
        if (stroke is! List || stroke.length.isOdd) return null;
        points += stroke.length ~/ 2;
        if (points > mostPoints) return null;
        final line = <Offset>[];
        for (var i = 0; i < stroke.length; i += 2) {
          final x = stroke[i];
          final y = stroke[i + 1];
          if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
            return null;
          }
          line.add(Offset(x.toDouble(), y.toDouble()));
        }
        parsed.add(line);
      }
      if (points == 0) return null;
      return DrawnInk(strokes: parsed, width: width.toDouble());
    }
    if (image is String) {
      final bytes = base64Decode(image);
      if (bytes.isEmpty || bytes.length > largestImage) return null;
      return ImageInk(bytes);
    }
    return null;
  }
}

/// The folder saved signatures live in, as `signatureDirectoryProvider`; null
/// where there is none (the web).
@Riverpod(keepAlive: true)
Future<String?> signatureDirectory(Ref ref) => savedSignatureDirectory();

/// The signatures and initials saved on this device, by file name, so oldest
/// first in each kind, as `savedSignaturesProvider` (a5-3d's menu). What
/// cannot be read is left out; a folder that cannot be read lists none.
@Riverpod(keepAlive: true)
class SavedSignatures extends _$SavedSignatures {
  @override
  Future<List<SavedSignature>> build() async {
    final directory = await ref.watch(signatureDirectoryProvider.future);
    if (directory == null) return const [];
    final List<SavedSignatureFile> files;
    try {
      files = await ref.read(engineServiceProvider).savedSignatures(directory);
    } on Exception {
      return const [];
    }
    return [
      for (final file in files) ?SavedSignature.fromFile(file.name, file.bytes),
    ];
  }

  /// Saves [signature] as a new file; the saved copy, or null when it could
  /// not be written.
  Future<SavedSignature?> add(SavedSignature signature) async {
    final directory = await ref.read(signatureDirectoryProvider.future);
    if (directory == null) return null;
    final kind = signature.initials ? 'initials' : 'signature';
    final saved = signature.named(
      '$kind-${DateTime.now().microsecondsSinceEpoch}.json',
    );
    try {
      await ref
          .read(engineServiceProvider)
          .writeSavedSignature(directory, saved.name, saved.toFile());
    } on Exception {
      return null;
    }
    if (!ref.mounted) return saved;
    state = AsyncData([...?state.value, saved]);
    return saved;
  }

  /// Deletes the saved [signature].
  Future<void> remove(SavedSignature signature) async {
    final directory = await ref.read(signatureDirectoryProvider.future);
    if (directory == null || signature.name.isEmpty) return;
    try {
      await ref
          .read(engineServiceProvider)
          .deleteSavedSignature(directory, signature.name);
    } on Exception {
      // Still listed until the next start: the file is there.
      return;
    }
    if (!ref.mounted) return;
    state = AsyncData([
      for (final each in state.value ?? const <SavedSignature>[])
        if (each.name != signature.name) each,
    ]);
  }
}

/// What a click on the page places in Fill & Sign (a5-3d), as
/// `signaturePlacementProvider`: null while nothing is to be placed.
@Riverpod(keepAlive: true)
class SignaturePlacement extends _$SignaturePlacement {
  @override
  SavedSignature? build() => null;

  /// A click on the page now places [signature].
  // A verb, as the other tools' notifiers name it.
  // ignore: use_setters_to_change_properties
  void choose(SavedSignature signature) => state = signature;

  /// Nothing more is placed.
  void end() => state = null;
}
