#include "file_manager.h"

#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windows.h>

#include <string>
#include <variant>

namespace {

constexpr char kChannelName[] = "ferman/files";

// |utf8| as UTF-16, or empty when it is not valid UTF-8.
std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int length = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                     utf8.data(), static_cast<int>(utf8.size()),
                                     nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring utf16(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                        static_cast<int>(utf8.size()), utf16.data(), length);
  return utf16;
}

// Opens the folder of |path| in File Explorer with the file selected; false
// when the file is gone or Explorer refuses. COM is started on this thread in
// main.cpp.
bool ShowInExplorer(const std::string& path) {
  std::wstring wide = Utf16FromUtf8(path);
  if (wide.empty()) {
    return false;
  }
  PIDLIST_ABSOLUTE item = ::ILCreateFromPathW(wide.c_str());
  if (item == nullptr) {
    return false;
  }
  HRESULT shown = ::SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
  ::ILFree(item);
  return SUCCEEDED(shown);
}

}  // namespace

FileChannel::FileChannel(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "show") {
      result->NotImplemented();
      return;
    }
    const auto* path = std::get_if<std::string>(call.arguments());
    result->Success(
        flutter::EncodableValue(path != nullptr && ShowInExplorer(*path)));
  });
}

FileChannel::~FileChannel() { channel_->SetMethodCallHandler(nullptr); }
