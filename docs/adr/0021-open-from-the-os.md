# ADR 0021: Opening files from the operating system

- **Status:** Proposed
- **Date:** 2026-10-17
- **Approval:** none yet (part of the M2 plan, which the owner approves before M2 starts)
- **Supersedes:** none
- **Superseded by:** none

## Context

M2 opens PDFs from everywhere the operating system offers: a double-click, "Open with", the Dock or the
taskbar, a path on the command line, and a second launch while Ferman is already running
([ROADMAP.md §6](../ROADMAP.md#6-m2-open-and-view) step 6). The file opens as a new tab, or focuses its
tab if it is already open. M2 also remembers recent files and reopens them after a restart (a1-4,
a1-4-m2, a1-9e).

What is already decided:

- The macOS App Sandbox stays on, with security-scoped bookmarks for recent files and the system's
  replacement directory for atomic saves, if M2 shows that both work ([Q18](../QUESTIONS.md#q18)).
- Files are chosen through the OS-native pickers ([ADR 0018](0018-native-file-pickers.md)).
- The Windows ProgID is registered by the installer in M5; Linux packaging is a Flatpak plus an
  AppImage in M5 ([Q12](../QUESTIONS.md#q12)).

What was open: [ARCHITECTURE.md §12](../ARCHITECTURE.md#12-platform-integration) named a Unix socket
for forwarding a second launch on Linux, but Flutter's Linux runner is a GtkApplication, which already
has single-instance forwarding over D-Bus; a socket would need its own path, permissions and cleanup.
Where recent files live had no decision either.

## Decision

We will forward through each platform's own single-instance mechanism and keep recent files in a Dart
store.

- **macOS.** `Info.plist` declares `CFBundleDocumentTypes` for `com.adobe.pdf` with the rank Alternate
  (Ferman never claims to be the owner of PDFs). `application(_:open:)` receives the files; events that
  arrive before Dart is ready are buffered and delivered once the method channel is up. macOS routes a
  second launch to the running app itself.
- **Windows.** The runner (`app/windows/runner/main.cpp`) takes a named mutex per user. A second
  instance sends its paths over a named pipe per user to the first and exits; the first brings its
  window forward.
- **Linux.** The runner drops `G_APPLICATION_NON_UNIQUE` and sets `G_APPLICATION_HANDLES_OPEN`, so
  GApplication's D-Bus uniqueness forwards a second launch's files to the running instance through the
  `open` signal. Without a session bus it falls back to non-unique, and each launch is its own
  instance.
- **Command line.** `main(List<String> args)` passes the paths in on every platform. A cold launch with
  a file skips the start screen.
- **Recent files.** A Dart `RecentFilesStore` in the app support directory, beside `settings.json`
  and written the same way: versioned JSON, a temp file, a flush and a rename
  ([ARCHITECTURE.md §12](../ARCHITECTURE.md#12-platform-integration), settings storage). An entry holds the path, the
  display name, the last-opened time, the pin, and on macOS a security-scoped bookmark created when the
  file was granted; it never holds document text. The engine supplies what Dart cannot: locale-aware
  sorting through `sort_keys` and page thumbnails, rendered at background priority, encoded to PNG in
  Dart and kept in the app cache directory. Encrypted documents get no thumbnail
  ([G109](../DESIGN_GAPS.md#g109)). An unreadable store is moved aside and an empty list is used, as
  for the settings file, never a crash.
- **macOS file access.** Both entitlement files gain `files.user-selected.read-write` and
  `files.bookmarks.app-scope`. A small platform service resolves bookmarks (and renews stale ones) and
  writes through the replacement directory; on Windows and Linux it does nothing.

## Consequences

### Positive

- No socket file, port or lock file to clean up; each platform's own mechanism handles the races of
  two launches at once.
- Recent files work under the sandbox, and the same store serves all three systems.
- The engine stays free of UI state; Dart keeps the list, the engine only sorts and renders.

### Negative

- Three native code paths to keep working; they can only be tested in part in CI. The owner checks
  double-click, "Open with", the second launch and cold start on each system, and GNOME and KDE on
  Linux (PROGRESS, pending owner checks).
- D-Bus uniqueness needs a session bus; without one (some minimal desktops, containers) a second launch
  opens a second window.
- A bookmark can go stale when a file moves; a1-9e's "Locate…" covers that case.

### Follow-up

- M2 step 6: the three runners, the store, the bookmarks and the tests (fakes for the picker, drop,
  open requests and file access; the store's round trip and corrupt-file handling; a Dart-side test of
  the Linux forwarding).
- M5: the Windows ProgID and the Linux desktop file and MIME registration in the installers and
  packages.

## Alternatives considered

- **A Unix socket on Linux** (the earlier text of ARCHITECTURE §12). Works, but duplicates what
  GApplication already does and needs its own file in the runtime directory.
- **A TCP port on localhost** on every platform. Simple to share, but any local process could connect,
  and it looks like a network use the privacy rules do not list ([ADR 0015](0015-privacy-and-network.md)).
- **Recent files in the engine.** The list is UI state with bookmarks that only the platform layer can
  use; the engine has no reason to hold it.
- **shared_preferences for recent files.** Set aside for settings in M1 because on macOS it writes to
  the user's preferences domain, outside the app data directory
  ([DEPENDENCIES.md](../DEPENDENCIES.md)); the same holds for recent files, which follow the settings
  file's pattern instead.

## References

- [Brief](../BRIEF.md) §7
- [ADR 0008](0008-file-safety-and-saving.md), [ADR 0015](0015-privacy-and-network.md),
  [ADR 0018](0018-native-file-pickers.md)
- [Q12](../QUESTIONS.md#q12), [Q18](../QUESTIONS.md#q18), [G25](../DESIGN_GAPS.md#g25),
  [G26](../DESIGN_GAPS.md#g26), [G28](../DESIGN_GAPS.md#g28), [G103](../DESIGN_GAPS.md#g103)
