import 'dart:io';
import 'dart:typed_data';

/// SHA-256 (FIPS 180-4) in plain Dart, so the bundle scanner needs no
/// dependency beyond the ones this package already has.
///
/// Feed bytes with [add], then read the digest once with [close].
final class Sha256 {
  /// Starts a new digest.
  new() {
    _state.setAll(0, _initial);
  }

  // The trailing `//` keeps the formatter from putting one word per line.

  /// The initial hash value: the first 32 bits of the fractional parts of
  /// the square roots of the first 8 primes.
  static const _initial = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];

  /// The round constants: the first 32 bits of the fractional parts of the
  /// cube roots of the first 64 primes.
  static const _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static const _mask = 0xffffffff;

  final _state = Uint32List(8);
  final _block = Uint8List(64);
  final _w = Uint32List(64);
  var _blockLength = 0;
  var _length = 0;
  var _closed = false;

  /// Adds [bytes] to the message.
  void add(List<int> bytes) {
    if (_closed) throw StateError('Sha256.add after close');
    _length += bytes.length;
    for (final byte in bytes) {
      _block[_blockLength++] = byte;
      if (_blockLength == 64) {
        _compress();
        _blockLength = 0;
      }
    }
  }

  /// Pads the message and returns the digest as 64 lowercase hex digits.
  String close() {
    if (_closed) throw StateError('Sha256.close called twice');
    final bits = _length * 8;
    _block[_blockLength++] = 0x80;
    if (_blockLength > 56) {
      _block.fillRange(_blockLength, 64, 0);
      _compress();
      _blockLength = 0;
    }
    _block.fillRange(_blockLength, 56, 0);
    for (var i = 0; i < 8; i++) {
      _block[63 - i] = (bits >> (8 * i)) & 0xff;
    }
    _compress();
    _closed = true;
    return [for (final word in _state) word.toRadixString(16).padLeft(8, '0')]
        .join();
  }

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

  void _compress() {
    final w = _w;
    final block = _block;
    for (var t = 0; t < 16; t++) {
      final i = t * 4;
      w[t] =
          (block[i] << 24) |
          (block[i + 1] << 16) |
          (block[i + 2] << 8) |
          block[i + 3];
    }
    for (var t = 16; t < 64; t++) {
      final x = w[t - 15];
      final y = w[t - 2];
      final sigma0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
      final sigma1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
      // Uint32List keeps the low 32 bits.
      w[t] = w[t - 16] + sigma0 + w[t - 7] + sigma1;
    }
    var a = _state[0];
    var b = _state[1];
    var c = _state[2];
    var d = _state[3];
    var e = _state[4];
    var f = _state[5];
    var g = _state[6];
    var h = _state[7];
    for (var t = 0; t < 64; t++) {
      final bigSigma1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final choose = (e & f) ^ (~e & g);
      final t1 = (h + bigSigma1 + choose + _k[t] + w[t]) & _mask;
      final bigSigma0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (bigSigma0 + majority) & _mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    _state[0] += a;
    _state[1] += b;
    _state[2] += c;
    _state[3] += d;
    _state[4] += e;
    _state[5] += f;
    _state[6] += g;
    _state[7] += h;
  }
}

/// The SHA-256 of [bytes], as 64 lowercase hex digits.
String sha256OfBytes(List<int> bytes) => (Sha256()..add(bytes)).close();

/// The SHA-256 of [file]'s contents, read in 64 KiB chunks.
///
/// Throws a [FileSystemException] when the file cannot be read.
String sha256OfFile(File file) {
  final digest = Sha256();
  final input = file.openSync();
  try {
    final buffer = Uint8List(64 * 1024);
    while (true) {
      final count = input.readIntoSync(buffer);
      if (count == 0) break;
      digest.add(Uint8List.sublistView(buffer, 0, count));
    }
  } finally {
    input.closeSync();
  }
  return digest.close();
}
