# ADR 0018: OS-native file pickers

- **Status:** Accepted (owner, [Q07](../QUESTIONS.md#q07), 2026-10-16)
- **Date:** 2026-10-14
- **Approval:** the owner, on 2026-10-16 ([Q07](../QUESTIONS.md#q07), option a)
- **Supersedes:** none (it adds an exception to the dialog rule in brief §6)
- **Superseded by:** none

## Context

The brief: "Dialogs and popups: custom popup-style widgets from the design system; never default
Material/Cupertino dialog implementations; no GetX." ([brief §6](../BRIEF.md)) M2 needs an open dialog
([brief §7](../BRIEF.md)), and M3 needs Save as.

Choosing a file or folder is different from other dialogs:

- **Access.** On sandboxed platforms the OS picker is what grants access. A sandboxed macOS app (the App
  Sandbox) can read or write a file the user did not pick only through the system open and save panels.
  Flatpak and Snap builds on Linux reach files through the xdg-desktop-portal file chooser. The web
  (P5) has only the browser's file APIs, and iOS and Android (P5) have the system document pickers. A
  custom file browser cannot work there at all.
- **Expectations.** People rely on the picker's favourites, recent places, cloud drives, network shares,
  search, tags and accessibility support. Rebuilding that would be a large project and would still feel
  foreign.
- **Today's builds.** The notarized DMG and the signed Windows installer planned for M5 are not
  sandboxed, but the Mac App Store, Flatpak, the web and mobile all are. Choosing the OS picker now
  avoids a second implementation later.

What the design shows:

- **a1-11** draws Ferman's own "Save as" sheet: file name, format ("PDF", "PDF/A-2b, for archiving",
  "Optimized for web"), options, and a "Where" dropdown with recent places ("Belgeler › Ev",
  "Masaüstü") ending in **"Other location…"**.
- **a6-2** (Split) and **a7-2** (Convert) have "Choose a folder…" for output.
- ⌘O and the Start screen's "Open file…" (a1-4, a1-5) open a file, but no board shows how
  ([G25](../DESIGN_GAPS.md#g25), [G26](../DESIGN_GAPS.md#g26)).
- The design already hands off to the OS where that is the norm: print offers "Use system dialog…"
  (a9-6), mobile sharing uses the system share sheet (a13-13), and the web start screen re-picks recent
  files with "Choose again…" through the browser (a14-2b).

## Decision

OS-native pickers are used for exactly three things, and are the only exception Ferman
adds to the custom-dialog rule:

1. **Open a file**: ⌘O / Ctrl+O, "Open file…" on the Start screen, "Pages from a file" and the
   "Combine files" inputs.
2. **Choose a save destination**: "Other location…" in the a1-11 sheet, and any other "Save as…" that
   needs a new location.
3. **Choose a folder**: "Choose a folder…" for outputs (a6-2, a7-2 and similar).

How:

- Through the **file_selector** package (BSD-3-Clause, maintained by the Flutter team): NSOpenPanel and
  NSSavePanel on macOS, IFileOpenDialog and IFileSaveDialog on Windows, GTK's file chooser on Linux
  (which can go through the xdg-desktop-portal; its behaviour in sandboxed builds is verified in M2),
  and the browser and mobile pickers in P5.
- **Ferman's own Save as sheet stays.** a1-11 is drawn as a Ferman component with file name, format,
  options and the "Where" shortcuts. Choosing "Other location…" hands off to the native save picker
  with the file name and type filled in; when it returns, the sheet shows the chosen folder and the user
  confirms in the sheet. Choosing a recent place saves without opening the native picker.
- The open picker is filtered to PDF (other types only once conversion exists, P3). Pickers start in the
  last-used folder, and the save picker suggests the document's name.
- Everything else stays custom: confirmations, password prompts, errors, options sheets, the unsaved
  changes prompt, menus and popovers ([ADR 0011](0011-flutter-state-navigation-components.md)).
- Handoffs the design itself draws as leaving Ferman (the system print dialog behind "Use system
  dialog…", the mobile share sheet) are OS features the user asks for; they follow the design and are
  not further exceptions.
- In code, all picker calls go through one `FilePickerService` interface, with a fake for widget and
  golden tests.
- On sandboxed platforms, access to recent files and folders is kept with the platform's mechanism
  (security-scoped bookmarks on macOS, portal document handles on Linux), stored with the recent-files
  list.

Before the owner's answer of 2026-10-16 ([Q07](../QUESTIONS.md#q07)), M1 built no file picker;
features that would open one stayed visible and disabled with "Available in a future version". M2
adds the open picker, M3 the native save-location handoff from a1-11, and a later milestone the
folder picker where it needs one.

## Consequences

### Positive

- Works under every sandbox Ferman may ship in, now and later, with one implementation.
- Users get the picker they know, with cloud drives, network locations and accessibility built in.
- The design's Save as sheet keeps its options and shortcuts; only the location step is native.

### Negative

- The native picker does not follow Ferman's design tokens, theme or density, and its language follows
  the OS, not Ferman's UI language. We accept this as platform convention.
- Native pickers cannot be driven by widget tests or goldens; tests use the fake service, and
  integration tests cover the handoff where the platform allows.
- Linux behaviour varies with the desktop environment and portal availability; Linux ships as a
  Flatpak on Flathub plus an AppImage from M5 ([Q12](../QUESTIONS.md#q12), 2026-10-16).
- Recent files on sandboxed platforms need bookmark handling, which adds code and edge cases (moved or
  deleted files, [G28](../DESIGN_GAPS.md#g28)).

### Follow-up

- M0: [Q07](../QUESTIONS.md#q07) asks the owner.
- M2: the open picker (under the brief §9 interim above if the owner has not answered yet), and
  bookmarks for recent files where the platform needs them. Drag and drop stays available alongside it.
- M3: the a1-11 sheet with the native "Other location…" handoff.
- The design gap entries [G25](../DESIGN_GAPS.md#g25) and [G26](../DESIGN_GAPS.md#g26) record the states
  to draw (opening into a running instance, the a1-11 handoff).

## Alternatives considered

- **A custom Ferman file browser.** Matches the design system, but cannot work under the macOS App
  Sandbox, Flatpak, the web or mobile, lacks cloud and network locations, and is a large accessibility
  burden.
- **Material or Cupertino file dialogs from packages.** Not native either, still need OS access for
  sandboxes, and the brief rules out Material and Cupertino dialog implementations.
- **Open only through drag and drop, recent files and "Open with".** Not enough: ⌘O is expected on every
  desktop platform, and the brief lists the open dialog for M2.
- **Native pickers for everything, including Save as options.** Platform save panels can host extra
  controls, but each platform differently, and the design draws a1-11 as a Ferman sheet.

## References

- [Brief](../BRIEF.md) §6, §7, §9
- [ARCHITECTURE.md](../ARCHITECTURE.md), section 12
- [ADR 0008](0008-file-safety-and-saving.md), [ADR 0011](0011-flutter-state-navigation-components.md)
- Artboards a1-4, a1-5, a1-11, a6-2, a7-2, a9-6, a13-13, a14-2b
- [G25](../DESIGN_GAPS.md#g25), [G26](../DESIGN_GAPS.md#g26), [G28](../DESIGN_GAPS.md#g28),
  [Q07](../QUESTIONS.md#q07), [Q12](../QUESTIONS.md#q12)
