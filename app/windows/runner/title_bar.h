#ifndef RUNNER_TITLE_BAR_H_
#define RUNNER_TITLE_BAR_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>

// Native support for Ferman's custom title bar on Windows (M1 phase H1).
//
// Ferman draws its own caption buttons in Flutter. Windows 11 shows the snap
// layout flyout only over a window's maximize button as the system knows it,
// so the Flutter side reports where its maximize button is
// ("setMaximizeButtonRect" on the "ferman/window" channel), and this class
// makes that area answer the system's hit test as HTMAXBUTTON:
//
// - the Flutter view (a child window) answers HTTRANSPARENT there, so the hit
//   test reaches the top-level window;
// - the top-level window answers HTMAXBUTTON there.
//
// The system then sends non-client mouse messages for that area instead of
// client ones, so Flutter no longer sees the pointer over its button. This
// class reports hover and press back ("maximizeButtonState") so the button
// can draw those states, and maximizes or restores the window on release.
//
// While the Flutter side has reported a rectangle, the top strip of the window
// is also its top resize edge (window_manager's hidden title bar removes the
// system's top frame).
//
// Until the Flutter side reports a rectangle, nothing changes: every message
// passes through.
class TitleBar {
 public:
  // Serves the "ferman/window" channel on |messenger| for |top_level|, the
  // runner window, and |flutter_view|, its Flutter child window.
  TitleBar(flutter::BinaryMessenger* messenger, HWND top_level,
           HWND flutter_view);
  ~TitleBar();

  TitleBar(const TitleBar&) = delete;
  TitleBar& operator=(const TitleBar&) = delete;

  // Handles |message| of the top-level window before anything else does;
  // returns a result when the message is handled here.
  std::optional<LRESULT> HandleTopLevelMessage(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM lparam);

 private:
  // The window procedure of the Flutter view, installed as a subclass.
  static LRESULT CALLBACK FlutterViewProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam,
                                          UINT_PTR subclass_id,
                                          DWORD_PTR ref_data);

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Whether |screen_point| (an lParam with screen coordinates) lies on the
  // reported maximize button.
  bool IsOverMaximizeButton(LPARAM screen_point) const;

  // HTTOP, HTTOPLEFT or HTTOPRIGHT when |screen_point| lies on the window's
  // top resize edge. window_manager's hidden title bar removes the system's
  // top frame, so the top strip of the client area takes its place.
  std::optional<LRESULT> TopResizeEdgeHit(LPARAM screen_point) const;

  void SetState(bool hovered, bool pressed);
  void TrackNonClientLeave();
  void CancelNonClientLeave();

  HWND top_level_;
  HWND flutter_view_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // The maximize button in the Flutter view's client coordinates, in logical
  // pixels as the Flutter side reports it; empty until then. It is turned into
  // physical pixels at the view's current scale on every hit test, so it stays
  // right when the window moves to a monitor with another scale.
  struct LogicalRect {
    double left;
    double top;
    double width;
    double height;
  };
  std::optional<LogicalRect> maximize_button_;
  bool hovered_ = false;
  bool pressed_ = false;
  bool tracking_leave_ = false;
};

#endif  // RUNNER_TITLE_BAR_H_
