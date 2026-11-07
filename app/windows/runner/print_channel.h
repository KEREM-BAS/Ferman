#ifndef RUNNER_PRINT_CHANNEL_H_
#define RUNNER_PRINT_CHANNEL_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

// The ferman/print channel (app/lib/platform/print_service.dart, a9-6,
// decision 29) on Windows: "begin" shows the system print dialog and starts a
// document on the printer it returns, "page" draws one page as Dart sends it,
// so a long document never waits in memory, "end" sends the document to the
// spooler and "abort" drops it.
class PrintChannel {
 public:
  PrintChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~PrintChannel();

  PrintChannel(const PrintChannel&) = delete;
  PrintChannel& operator=(const PrintChannel&) = delete;

 private:
  bool Begin(const std::string& name, bool fit);
  bool Page(const flutter::EncodableMap& page);
  bool Finish(bool abort);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  // The printer's device context while a document is under way.
  HDC dc_ = nullptr;
  // Whether pages are scaled to the printable area, or printed at their size.
  bool fit_ = true;
};

#endif  // RUNNER_PRINT_CHANNEL_H_
