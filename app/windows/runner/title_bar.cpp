#include "title_bar.h"

#include <commctrl.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <cmath>
#include <variant>

namespace {

constexpr char kChannelName[] = "ferman/window";
constexpr UINT_PTR kSubclassId = 1;

// The double stored under |key| in |map|, or std::nullopt.
std::optional<double> GetDouble(const flutter::EncodableMap& map,
                                const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  return std::nullopt;
}

}  // namespace

TitleBar::TitleBar(flutter::BinaryMessenger* messenger, HWND top_level,
                   HWND flutter_view)
    : top_level_(top_level), flutter_view_(flutter_view) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
  SetWindowSubclass(flutter_view_, FlutterViewProc, kSubclassId,
                    reinterpret_cast<DWORD_PTR>(this));
}

TitleBar::~TitleBar() {
  RemoveWindowSubclass(flutter_view_, FlutterViewProc, kSubclassId);
  channel_->SetMethodCallHandler(nullptr);
}

void TitleBar::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "setMaximizeButtonRect") {
    result->NotImplemented();
    return;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (args == nullptr) {
    // null clears the rectangle: the area is ordinary client area again.
    maximize_button_.reset();
    CancelNonClientLeave();
    SetState(false, false);
    result->Success();
    return;
  }
  const auto left = GetDouble(*args, "left");
  const auto top = GetDouble(*args, "top");
  const auto width = GetDouble(*args, "width");
  const auto height = GetDouble(*args, "height");
  if (!left || !top || !width || !height || *width <= 0 || *height <= 0) {
    result->Error("bad-arguments",
                  "setMaximizeButtonRect needs left, top, width and height");
    return;
  }
  maximize_button_ = LogicalRect{*left, *top, *width, *height};
  result->Success();
}

bool TitleBar::IsOverMaximizeButton(LPARAM screen_point) const {
  if (!maximize_button_) {
    return false;
  }
  POINT point{GET_X_LPARAM(screen_point), GET_Y_LPARAM(screen_point)};
  if (!ScreenToClient(flutter_view_, &point)) {
    return false;
  }
  // Flutter's logical pixels are physical pixels divided by the view's
  // scale; FlutterDesktopGetDpiForHWND gives the DPI the engine itself uses
  // for that scale (and avoids a hard import of GetDpiForWindow).
  const double scale = FlutterDesktopGetDpiForHWND(flutter_view_) / 96.0;
  const LogicalRect& r = *maximize_button_;
  const RECT physical{
      static_cast<LONG>(std::floor(r.left * scale)),
      static_cast<LONG>(std::floor(r.top * scale)),
      static_cast<LONG>(std::ceil((r.left + r.width) * scale)),
      static_cast<LONG>(std::ceil((r.top + r.height) * scale)),
  };
  return PtInRect(&physical, point) != 0;
}

void TitleBar::SetState(bool hovered, bool pressed) {
  if (hovered == hovered_ && pressed == pressed_) {
    return;
  }
  hovered_ = hovered;
  pressed_ = pressed;
  channel_->InvokeMethod(
      "maximizeButtonState",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
          {flutter::EncodableValue("hovered"), flutter::EncodableValue(hovered)},
          {flutter::EncodableValue("pressed"), flutter::EncodableValue(pressed)},
      }));
}

void TitleBar::CancelNonClientLeave() {
  if (!tracking_leave_) {
    return;
  }
  TRACKMOUSEEVENT track{};
  track.cbSize = sizeof(track);
  track.dwFlags = TME_CANCEL | TME_LEAVE | TME_NONCLIENT;
  track.hwndTrack = top_level_;
  TrackMouseEvent(&track);
  tracking_leave_ = false;
}

void TitleBar::TrackNonClientLeave() {
  if (tracking_leave_) {
    return;
  }
  TRACKMOUSEEVENT track{};
  track.cbSize = sizeof(track);
  track.dwFlags = TME_LEAVE | TME_NONCLIENT;
  track.hwndTrack = top_level_;
  tracking_leave_ = TrackMouseEvent(&track) != 0;
}

std::optional<LRESULT> TitleBar::HandleTopLevelMessage(HWND hwnd,
                                                       UINT message,
                                                       WPARAM wparam,
                                                       LPARAM lparam) {
  if (message == WM_NCMOUSELEAVE) {
    // Always: leave-tracking may have started before the rectangle was
    // cleared.
    tracking_leave_ = false;
    if (maximize_button_) {
      SetState(false, false);
    }
    return std::nullopt;
  }
  if (!maximize_button_) {
    return std::nullopt;
  }
  switch (message) {
    case WM_NCHITTEST:
      if (IsOverMaximizeButton(lparam)) {
        return HTMAXBUTTON;
      }
      return std::nullopt;
    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON) {
        TrackNonClientLeave();
        SetState(true, pressed_);
        return 0;
      }
      SetState(false, false);
      return std::nullopt;
    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTMAXBUTTON) {
        // Handled here so the system does not draw or track its own caption
        // button.
        SetState(true, true);
        return 0;
      }
      return std::nullopt;
    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON) {
        const bool was_pressed = pressed_;
        SetState(true, false);
        if (was_pressed) {
          ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
        }
        return 0;
      }
      SetState(hovered_, false);
      return std::nullopt;
    default:
      return std::nullopt;
  }
}

LRESULT CALLBACK TitleBar::FlutterViewProc(HWND hwnd, UINT message,
                                           WPARAM wparam, LPARAM lparam,
                                           UINT_PTR subclass_id,
                                           DWORD_PTR ref_data) {
  auto* self = reinterpret_cast<TitleBar*>(ref_data);
  if (message == WM_NCHITTEST && self->IsOverMaximizeButton(lparam)) {
    // Let the hit test fall through to the top-level window, which answers
    // HTMAXBUTTON.
    return HTTRANSPARENT;
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}
