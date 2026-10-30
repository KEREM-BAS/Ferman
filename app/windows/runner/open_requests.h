#ifndef RUNNER_OPEN_REQUESTS_H_
#define RUNNER_OPEN_REQUESTS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

// Files the system asks Ferman to open (ADR 0021,
// app/lib/platform/open_requests.dart): the command line, and a second launch
// forwarded to the first instance over a named pipe per user.

// The files on the command line, made absolute against the current directory
// and encoded in UTF-8. A second instance runs in another directory, so the
// first could not resolve its relative paths.
std::vector<std::string> GetCommandLinePaths();

// The window message the pipe thread posts with a later launch's files; its
// LPARAM owns a heap-allocated std::vector<std::string>.
UINT OpenRequestMessage();

// One instance per user and session: the owner of a named mutex serves a pipe
// that only this user may open; a later launch sends its files there and
// exits once the first instance has taken them.
class SingleInstance {
 public:
  SingleInstance();
  ~SingleInstance();

  SingleInstance(const SingleInstance&) = delete;
  SingleInstance& operator=(const SingleInstance&) = delete;

  // Whether this launch owns the mutex: no other instance of this user
  // serves in this session.
  bool IsFirst() const { return first_; }

  // Tries again to own the mutex, after a forward failed (the first instance
  // was quitting, or never reached its pipe); whether it now does.
  bool TakeOver();

  // Sends |paths| (none: just bring the window forward) to the first
  // instance, waiting up to five seconds for its pipe while it starts. True
  // once that instance's window has taken them; false when it could not be
  // reached, runs as another user or did not take them, and this launch then
  // runs on its own.
  bool Forward(const std::vector<std::string>& paths) const;

  // Serves the pipe on a thread of its own, posting each request to |window|
  // as OpenRequestMessage(). The thread ends with the process.
  void Serve(HWND window) const;

 private:
  HANDLE mutex_ = nullptr;
  bool first_ = true;
  std::wstring sid_;
  std::wstring pipe_name_;
};

// The "ferman/open" channel: keeps the files until Dart calls "ready", which
// answers with them, then sends each request as "open".
class OpenChannel {
 public:
  explicit OpenChannel(flutter::BinaryMessenger* messenger);
  ~OpenChannel();

  OpenChannel(const OpenChannel&) = delete;
  OpenChannel& operator=(const OpenChannel&) = delete;

  // Sends |paths| to Dart, or keeps them until Dart is ready.
  void Receive(std::vector<std::string> paths);

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::vector<std::string> kept_;
  bool ready_ = false;
};

#endif  // RUNNER_OPEN_REQUESTS_H_
