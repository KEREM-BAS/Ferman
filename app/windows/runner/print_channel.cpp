#include "print_channel.h"

// windows.h (through print_channel.h) must come before commdlg.h.
#include <commdlg.h>

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <optional>
#include <variant>
#include <vector>

namespace {

constexpr char kChannelName[] = "ferman/print";

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

const flutter::EncodableValue* Find(const flutter::EncodableMap& map,
                                    const char* key) {
  auto found = map.find(flutter::EncodableValue(key));
  return found == map.end() ? nullptr : &found->second;
}

std::optional<int64_t> IntOf(const flutter::EncodableMap& map,
                             const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* narrow = std::get_if<int32_t>(value)) {
    return *narrow;
  }
  if (const auto* large = std::get_if<int64_t>(value)) {
    return *large;
  }
  return std::nullopt;
}

std::optional<double> DoubleOf(const flutter::EncodableMap& map,
                               const char* key) {
  const flutter::EncodableValue* value = Find(map, key);
  const auto* number = value == nullptr ? nullptr : std::get_if<double>(value);
  return number == nullptr ? std::nullopt : std::optional<double>(*number);
}

}  // namespace

PrintChannel::PrintChannel(flutter::BinaryMessenger* messenger, HWND window)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance())),
      window_(window) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(call.arguments());
    const std::string& method = call.method_name();
    if (method == "begin") {
      std::string name;
      bool fit = true;
      if (arguments != nullptr) {
        if (const auto* value = Find(*arguments, "name")) {
          if (const auto* text = std::get_if<std::string>(value)) {
            name = *text;
          }
        }
        if (const auto* value = Find(*arguments, "fit")) {
          if (const auto* flag = std::get_if<bool>(value)) {
            fit = *flag;
          }
        }
      }
      result->Success(flutter::EncodableValue(Begin(name, fit)));
    } else if (method == "page") {
      result->Success(
          flutter::EncodableValue(arguments != nullptr && Page(*arguments)));
    } else if (method == "end") {
      result->Success(flutter::EncodableValue(Finish(false)));
    } else if (method == "abort") {
      result->Success(flutter::EncodableValue(Finish(true)));
    } else {
      result->NotImplemented();
    }
  });
}

PrintChannel::~PrintChannel() {
  channel_->SetMethodCallHandler(nullptr);
  Finish(true);
}

bool PrintChannel::Begin(const std::string& name, bool fit) {
  Finish(true);
  PRINTDLGEXW dialog = {};
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = window_;
  // Dart sends the pages chosen in Ferman's dialog; the system dialog picks
  // the printer, the copies and both sides.
  dialog.Flags = PD_RETURNDC | PD_NOPAGENUMS | PD_NOSELECTION |
                 PD_NOCURRENTPAGE | PD_USEDEVMODECOPIESANDCOLLATE;
  dialog.nStartPage = START_PAGE_GENERAL;
  HRESULT shown = ::PrintDlgExW(&dialog);
  if (dialog.hDevMode != nullptr) {
    ::GlobalFree(dialog.hDevMode);
  }
  if (dialog.hDevNames != nullptr) {
    ::GlobalFree(dialog.hDevNames);
  }
  if (FAILED(shown) || dialog.dwResultAction != PD_RESULT_PRINT ||
      dialog.hDC == nullptr) {
    if (dialog.hDC != nullptr) {
      ::DeleteDC(dialog.hDC);
    }
    return false;
  }
  std::wstring title = Utf16FromUtf8(name);
  DOCINFOW document = {};
  document.cbSize = sizeof(document);
  document.lpszDocName = title.c_str();
  if (::StartDocW(dialog.hDC, &document) <= 0) {
    ::DeleteDC(dialog.hDC);
    return false;
  }
  dc_ = dialog.hDC;
  fit_ = fit;
  return true;
}

bool PrintChannel::Page(const flutter::EncodableMap& page) {
  if (dc_ == nullptr) {
    return false;
  }
  std::optional<int64_t> width = IntOf(page, "width");
  std::optional<int64_t> height = IntOf(page, "height");
  std::optional<double> width_points = DoubleOf(page, "widthPoints");
  std::optional<double> height_points = DoubleOf(page, "heightPoints");
  const flutter::EncodableValue* value = Find(page, "pixels");
  const auto* pixels =
      value == nullptr ? nullptr : std::get_if<std::vector<uint8_t>>(value);
  if (!width || !height || !width_points || !height_points ||
      pixels == nullptr || *width <= 0 || *height <= 0 ||
      *width_points <= 0 || *height_points <= 0 || *width > INT32_MAX / 4 ||
      static_cast<uint64_t>(pixels->size()) <
          static_cast<uint64_t>(*width) * static_cast<uint64_t>(*height) * 4) {
    return false;
  }
  if (::StartPage(dc_) <= 0) {
    return false;
  }
  // The printable area, in device pixels, from its top-left corner.
  double area_width = ::GetDeviceCaps(dc_, HORZRES);
  double area_height = ::GetDeviceCaps(dc_, VERTRES);
  double drawn_width = *width_points / 72.0 * ::GetDeviceCaps(dc_, LOGPIXELSX);
  double drawn_height =
      *height_points / 72.0 * ::GetDeviceCaps(dc_, LOGPIXELSY);
  if (fit_) {
    double scale =
        std::min(area_width / drawn_width, area_height / drawn_height);
    drawn_width *= scale;
    drawn_height *= scale;
  }
  BITMAPINFO bitmap = {};
  bitmap.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap.bmiHeader.biWidth = static_cast<LONG>(*width);
  // Negative: the top row comes first.
  bitmap.bmiHeader.biHeight = -static_cast<LONG>(*height);
  bitmap.bmiHeader.biPlanes = 1;
  bitmap.bmiHeader.biBitCount = 32;
  bitmap.bmiHeader.biCompression = BI_RGB;
  ::SetStretchBltMode(dc_, HALFTONE);
  ::SetBrushOrgEx(dc_, 0, 0, nullptr);
  int drawn = ::StretchDIBits(
      dc_, static_cast<int>((area_width - drawn_width) / 2),
      static_cast<int>((area_height - drawn_height) / 2),
      static_cast<int>(drawn_width), static_cast<int>(drawn_height), 0, 0,
      static_cast<int>(*width), static_cast<int>(*height), pixels->data(),
      &bitmap, DIB_RGB_COLORS, SRCCOPY);
  bool ended = ::EndPage(dc_) > 0;
  return ended && drawn != 0 && drawn != GDI_ERROR;
}

bool PrintChannel::Finish(bool abort) {
  if (dc_ == nullptr) {
    return false;
  }
  bool sent = false;
  if (abort) {
    ::AbortDoc(dc_);
  } else {
    sent = ::EndDoc(dc_) > 0;
  }
  ::DeleteDC(dc_);
  dc_ = nullptr;
  return sent;
}
