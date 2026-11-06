import 'dart:io';

/// The mode's write bits for owner, group and others (octal 222).
const int _writeBits = 0x92;

/// Whether a file is at [path]; false when it cannot be told.
Future<bool> fileExists(String path) async {
  // One stat call: small enough for the sheet's Save.
  try {
    return File(path).existsSync();
  } on FileSystemException {
    return false;
  }
}

/// Whether the file at [path] says no one may write it: every write bit off
/// (on Windows, its read-only attribute). A folder or a volume that refuses
/// shows at Save instead (a11-7d).
bool fileReadOnly(String path) {
  final stat = FileStat.statSync(path);
  return stat.type == FileSystemEntityType.file && stat.mode & _writeBits == 0;
}
