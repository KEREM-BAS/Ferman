#ifndef RUNNER_FILE_MANAGER_H_
#define RUNNER_FILE_MANAGER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// The ferman/files channel (app/lib/platform/file_access.dart) on Windows:
// "openUrl", and "show", which selects a file in File Explorer (a1-9b). Bookmarks are
// macOS only, so "bookmark", "access" and "release" are not implemented and
// Dart treats them as none.
class FileChannel {
 public:
  explicit FileChannel(flutter::BinaryMessenger* messenger);
  ~FileChannel();

  FileChannel(const FileChannel&) = delete;
  FileChannel& operator=(const FileChannel&) = delete;

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_FILE_MANAGER_H_
