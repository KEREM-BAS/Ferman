#include "open_requests.h"

#include <flutter/standard_method_codec.h>
#include <sddl.h>
#include <shellapi.h>

#include <cstdint>
#include <thread>
#include <utility>

#include "utils.h"

namespace {

constexpr char kChannelName[] = "ferman/open";

#ifdef _DEBUG
// A debug build (flutter run, the integration test) never hands its files to
// an installed Ferman, nor takes those of a later launch of one.
constexpr wchar_t kName[] = L"io.github.kerembas.ferman.debug";
#else
constexpr wchar_t kName[] = L"io.github.kerembas.ferman";
#endif

// The most a request may hold: thousands of paths.
constexpr uint32_t kMaxRequestBytes = 1 << 20;

// How often, and how long apart, a later launch tries the first one's pipe.
constexpr int kForwardAttempts = 50;
constexpr DWORD kForwardIntervalMs = 100;

// What the first instance answers once its window has taken a request.
constexpr char kAccepted = 1;

// The string form of the SID of |token|'s user, or an empty string.
std::wstring TokenUserSid(HANDLE token) {
  DWORD size = 0;
  ::GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  std::vector<BYTE> buffer(size);
  std::wstring sid;
  if (size > 0 && ::GetTokenInformation(token, TokenUser, buffer.data(), size,
                                        &size)) {
    LPWSTR text = nullptr;
    if (::ConvertSidToStringSidW(
            reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &text)) {
      sid = text;
      ::LocalFree(text);
    }
  }
  return sid;
}

// The string form of the SID of |process|'s user, or an empty string.
std::wstring ProcessUserSid(HANDLE process) {
  HANDLE token = nullptr;
  if (!::OpenProcessToken(process, TOKEN_QUERY, &token)) {
    return std::wstring();
  }
  std::wstring sid = TokenUserSid(token);
  ::CloseHandle(token);
  return sid;
}

// Whether the process at the other end of |pipe| runs as |sid|: a later
// launch talks only to this user's first instance, never to a pipe another
// account created under the same name.
bool ServedBy(HANDLE pipe, const std::wstring& sid) {
  ULONG server = 0;
  if (sid.empty() || !::GetNamedPipeServerProcessId(pipe, &server)) {
    return false;
  }
  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, server);
  if (process == nullptr) {
    return false;
  }
  const bool same = ProcessUserSid(process) == sid;
  ::CloseHandle(process);
  return same;
}

// Reads exactly |size| bytes (at most kMaxRequestBytes) from |pipe| into
// |data|.
bool ReadExactly(HANDLE pipe, void* data, size_t size) {
  auto* bytes = static_cast<char*>(data);
  while (size > 0) {
    DWORD read = 0;
    if (!::ReadFile(pipe, bytes, static_cast<DWORD>(size), &read, nullptr) ||
        read == 0) {
      return false;
    }
    bytes += read;
    size -= read;
  }
  return true;
}

// Writes all |size| bytes (at most kMaxRequestBytes) of |data| to |pipe|.
bool WriteAll(HANDLE pipe, const void* data, size_t size) {
  DWORD written = 0;
  return ::WriteFile(pipe, data, static_cast<DWORD>(size), &written,
                     nullptr) &&
         written == size;
}

// |data| split at each NUL, without empty parts.
std::vector<std::string> SplitPaths(const std::string& data) {
  std::vector<std::string> paths;
  size_t start = 0;
  while (start < data.size()) {
    size_t end = data.find('\0', start);
    if (end == std::string::npos) {
      end = data.size();
    }
    if (end > start) {
      paths.emplace_back(data, start, end - start);
    }
    start = end + 1;
  }
  return paths;
}

// Serves one connection: a request is its length (4 bytes, little endian)
// and its NUL-separated UTF-8 paths. Once |window| has the request in its
// queue the client gets kAccepted; a window that is gone gets nothing, so the
// client runs on its own.
void ServeClient(HANDLE pipe, HWND window) {
  uint32_t size = 0;
  if (!ReadExactly(pipe, &size, sizeof(size)) || size > kMaxRequestBytes) {
    return;
  }
  std::string data(size, '\0');
  if (size > 0 && !ReadExactly(pipe, data.data(), size)) {
    return;
  }
  auto* paths = new std::vector<std::string>(SplitPaths(data));
  if (!::PostMessageW(window, OpenRequestMessage(), 0,
                      reinterpret_cast<LPARAM>(paths))) {
    delete paths;
    return;
  }
  WriteAll(pipe, &kAccepted, sizeof(kAccepted));
  ::FlushFileBuffers(pipe);
}

}  // namespace

std::vector<std::string> GetCommandLinePaths() {
  std::vector<std::string> paths;
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return paths;
  }
  // Skip the first argument: it is the binary.
  for (int i = 1; i < argc; i++) {
    const DWORD size = ::GetFullPathNameW(argv[i], 0, nullptr, nullptr);
    if (size == 0) {
      continue;
    }
    std::wstring full(size, L'\0');
    const DWORD length =
        ::GetFullPathNameW(argv[i], size, full.data(), nullptr);
    if (length == 0 || length >= size) {
      continue;
    }
    full.resize(length);
    std::string path = Utf8FromUtf16(full.c_str());
    if (!path.empty()) {
      paths.push_back(std::move(path));
    }
  }
  ::LocalFree(argv);
  return paths;
}

UINT OpenRequestMessage() {
  static const UINT message =
      ::RegisterWindowMessageW(L"io.github.kerembas.ferman.open");
  return message;
}

SingleInstance::SingleInstance() : sid_(ProcessUserSid(::GetCurrentProcess())) {
  DWORD session = 0;
  ::ProcessIdToSessionId(::GetCurrentProcessId(), &session);
  // Local\ names are per session already; the pipe namespace is not.
  const std::wstring mutex_name =
      std::wstring(L"Local\\") + kName + L"-" + sid_;
  pipe_name_ = std::wstring(L"\\\\.\\pipe\\") + kName + L"-" + sid_ + L"-" +
               std::to_wstring(session);
  mutex_ = ::CreateMutexW(nullptr, FALSE, mutex_name.c_str());
  first_ = mutex_ == nullptr || TakeOver();
}

SingleInstance::~SingleInstance() {
  if (mutex_ != nullptr) {
    ::CloseHandle(mutex_);
  }
}

bool SingleInstance::TakeOver() {
  if (mutex_ == nullptr) {
    return false;
  }
  // Owned until this thread ends; a first instance that quit leaves it
  // abandoned, which a later launch takes over too.
  const DWORD wait = ::WaitForSingleObject(mutex_, 0);
  first_ = wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED;
  return first_;
}

bool SingleInstance::Forward(const std::vector<std::string>& paths) const {
  std::string data;
  for (const std::string& path : paths) {
    data += path;
    data.push_back('\0');
  }
  if (data.size() > kMaxRequestBytes) {
    return false;
  }
  const uint32_t size = static_cast<uint32_t>(data.size());
  for (int attempt = 0; attempt < kForwardAttempts; attempt++) {
    // SECURITY_IDENTIFICATION: the server may learn who sent the request,
    // never act as this user.
    HANDLE pipe = ::CreateFileW(
        pipe_name_.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr,
        OPEN_EXISTING, SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION,
        nullptr);
    if (pipe == INVALID_HANDLE_VALUE) {
      // The first instance may still be starting, or serving another launch.
      if (::GetLastError() != ERROR_PIPE_BUSY ||
          !::WaitNamedPipeW(pipe_name_.c_str(), kForwardIntervalMs)) {
        ::Sleep(kForwardIntervalMs);
      }
      continue;
    }
    bool accepted = false;
    if (ServedBy(pipe, sid_)) {
      // The first instance may bring its window forward: this launch is the
      // user's, so it holds the foreground.
      ULONG server = 0;
      if (::GetNamedPipeServerProcessId(pipe, &server)) {
        ::AllowSetForegroundWindow(server);
      }
      char answer = 0;
      accepted = WriteAll(pipe, &size, sizeof(size)) &&
                 (size == 0 || WriteAll(pipe, data.data(), size)) &&
                 ReadExactly(pipe, &answer, sizeof(answer)) &&
                 answer == kAccepted;
    }
    ::CloseHandle(pipe);
    return accepted;
  }
  return false;
}

void SingleInstance::Serve(HWND window) const {
  // Only this user may connect: not even administrators or the system.
  const std::wstring sddl = L"D:P(A;;GA;;;" + sid_ + L")";
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (sid_.empty() ||
      !::ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) {
    return;
  }
  std::thread([name = pipe_name_, window, descriptor]() {
    SECURITY_ATTRIBUTES attributes{static_cast<DWORD>(sizeof(attributes)),
                                   descriptor, FALSE};
    for (;;) {
      // FILE_FLAG_FIRST_PIPE_INSTANCE: never serve a name another process
      // holds.
      HANDLE pipe = ::CreateNamedPipeW(
          name.c_str(), PIPE_ACCESS_DUPLEX | FILE_FLAG_FIRST_PIPE_INSTANCE,
          PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
              PIPE_REJECT_REMOTE_CLIENTS,
          1, 64, 64 * 1024, 0, &attributes);
      if (pipe == INVALID_HANDLE_VALUE) {
        break;
      }
      if (::ConnectNamedPipe(pipe, nullptr) ||
          ::GetLastError() == ERROR_PIPE_CONNECTED) {
        ServeClient(pipe, window);
      }
      ::DisconnectNamedPipe(pipe);
      ::CloseHandle(pipe);
    }
    ::LocalFree(descriptor);
  }).detach();
}

OpenChannel::OpenChannel(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "ready") {
      result->NotImplemented();
      return;
    }
    flutter::EncodableList kept(kept_.begin(), kept_.end());
    kept_.clear();
    ready_ = true;
    result->Success(flutter::EncodableValue(std::move(kept)));
  });
}

OpenChannel::~OpenChannel() { channel_->SetMethodCallHandler(nullptr); }

void OpenChannel::Receive(std::vector<std::string> paths) {
  if (paths.empty()) {
    return;
  }
  if (!ready_) {
    kept_.insert(kept_.end(), std::make_move_iterator(paths.begin()),
                 std::make_move_iterator(paths.end()));
    return;
  }
  channel_->InvokeMethod(
      "open", std::make_unique<flutter::EncodableValue>(
                  flutter::EncodableList(paths.begin(), paths.end())));
}
