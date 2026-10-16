import 'dart:convert';
import 'dart:io';

import 'package:checks/src/sha256.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // FIPS 180-4 examples and the NIST test vectors.
  final vectors = {
    '': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'abc': 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq':
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno'
            'ijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu':
        'cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1',
  };

  test('matches the published test vectors', () {
    for (final MapEntry(key: message, value: digest) in vectors.entries) {
      expect(sha256OfBytes(ascii.encode(message)), digest, reason: message);
    }
  });

  test('hashes a million bytes', () {
    expect(
      sha256OfBytes(List.filled(1000000, 0x61)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });

  test('gives the same digest however the bytes are split', () {
    // Lengths around the 56-byte padding limit and the 64-byte block.
    for (final length in [55, 56, 57, 63, 64, 65, 119, 128, 1000]) {
      final bytes = [for (var i = 0; i < length; i++) (i * 31 + 7) & 0xff];
      final whole = sha256OfBytes(bytes);
      for (final cut in {0, 1, length ~/ 2, length - 1, length}) {
        final split = Sha256()
          ..add(bytes.sublist(0, cut))
          ..add(bytes.sublist(cut));
        expect(split.close(), whole, reason: 'length $length, cut at $cut');
      }
    }
  });

  test('reads a file larger than its buffer', () {
    final dir = Directory.systemTemp.createTempSync('sha256_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bytes = [for (var i = 0; i < 200003; i++) (i * 131) & 0xff];
    final file = File(p.join(dir.path, 'data.bin'))..writeAsBytesSync(bytes);
    expect(sha256OfFile(file), sha256OfBytes(bytes));
  });

  test('refuses to be used after close', () {
    final digest = Sha256()..close();
    expect(() => digest.add([1]), throwsStateError);
    expect(digest.close, throwsStateError);
  });
}
