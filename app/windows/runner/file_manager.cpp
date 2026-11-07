#include "file_manager.h"

// windows.h must come before shellapi.h and shlobj.h.
#include <windows.h>

#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <shlobj.h>

#include <algorithm>
#include <cctype>
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

// Opens |url| with the system's handler: only what the engine offers, after
// the app's prompt (G145).
bool OpenUrl(const std::string& url) {
  std::string scheme = url.substr(0, url.find(':'));
  std::transform(scheme.begin(), scheme.end(), scheme.begin(),
                 [](unsigned char c) { return std::tolower(c); });
  if (scheme != "http" && scheme != "https" && scheme != "mailto") {
    return false;
  }
  std::wstring wide = Utf16FromUtf8(url);
  if (wide.empty()) {
    return false;
  }
  HINSTANCE opened = ::ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr,
                                     nullptr, SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(opened) > 32;
}

}  // namespace

FileChannel::FileChannel(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    const auto* text = std::get_if<std::string>(call.arguments());
    if (call.method_name() == "openUrl") {
      result->Success(flutter::EncodableValue(text != nullptr && OpenUrl(*text)));
      return;
    }
    if (call.method_name() != "show") {
      result->NotImplemented();
      return;
    }
    result->Success(
        flutter::EncodableValue(text != nullptr && ShowInExplorer(*text)));
  });
}

FileChannel::~FileChannel() { channel_->SetMethodCallHandler(nullptr); }
