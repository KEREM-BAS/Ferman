# ADR 0023: Updates, the network stack and release packaging

- **Status:** Proposed
- **Date:** 2026-11-09
- **Approval:** none yet
- **Supersedes:** none
- **Superseded by:** none

## Context

M5 ([ROADMAP §9](../ROADMAP.md#9-m5-release-pipeline)) ships Ferman: a notarized macOS DMG, a
signed Windows installer, Linux packages ([Q12](../QUESTIONS.md#q12)), GitHub Releases, automatic
updates, and Homebrew and winget manifests. Three things are fixed already:

- [ADR 0015](0015-privacy-and-network.md) and ARCHITECTURE §10.2: `ferman-api::net` is the only code
  with an HTTP client. Every request names its purpose, is checked against the user's switch and is
  written to the local network activity log. TLS uses the OS trust store; no cookies, no identifiers.
- [Q15](../QUESTIONS.md#q15): one static, signed manifest per channel (Stable, Beta) on GitHub; the
  release files on GitHub Releases; the version comparison on the device.
- [ADR 0016](0016-dependency-licence-policy.md): permissive licences only; anything unusual goes to
  the owner.

The ROADMAP's dependency table leaves three choices "to check": the HTTP client, the update
framework and the installer tooling. The M5 survey (2026-11-09) resolved each against `deny.toml` in
scratch crates outside the repository.

Constraints found:

- **One gateway.** Sparkle (macOS) and WinSparkle (Windows) fetch their feeds and archives with their
  own HTTP code, so as whole frameworks they bypass the gateway and the activity log.
- **The macOS App Sandbox.** A sandboxed app cannot replace its own bundle in `/Applications`. The
  helper that does it must run outside the sandbox. `SMAppService` needs macOS 13; the minimum is 12
  ([Q03](../QUESTIONS.md#q03)). `Release.entitlements` has no `network.client` yet.
- **Shipped installer code.** An installer's stub and uninstaller ship to users, so their licence
  counts. WiX is MS-RL; Inno Setup has its own zlib-style licence; NSIS is zlib with optional
  bzip2/CPL modules; MSIX ships no stub but auto-updates through App Installer's own HTTP and has
  no classic ProgID.
- **AppImage.** The type-2 runtime links libfuse (LGPL-2.1) statically, and linuxdeploy bundles GTK
  and GLib (LGPL-2.1) by default.

## Decision

### Network stack

- `ferman-api::net` uses **ureq 3** (blocking, HTTP/1.1) with **rustls 0.23 on the `ring` provider**
  and **rustls-platform-verifier** for the OS trust store. Features: `rustls-no-provider`,
  `platform-verifier`, `win-system-proxy`; default features off (they pull webpki-roots,
  CDLA-Permissive-2.0). The provider and root store are set explicitly, because ureq's defaults
  panic in library code when they are missing.
- The user agent is overridden to `Ferman/<version> (<os>; <arch>)`. Cookies stay off (ureq's
  `cookies` feature is not enabled).
- Proxy: the environment variables on every system, the per-user registry setting on Windows
  (ureq's `win-system-proxy`; `net` parses the `http=…;https=…` form itself), and the system proxy on
  macOS through `system-configuration`. PAC and WPAD are not supported; Settings says so.
- Requests run on a job thread (ADR 0009); no new async runtime.
- `deny.toml`: `ureq` with `wrappers = ["ferman-api"]`; reqwest, hyper, minreq, attohttpc, isahc,
  curl, surf, webpki-roots, webpki-root-certs, aws-lc-rs, aws-lc-sys, openssl-sys and native-tls
  banned. `tools/checks` `crate_graph` gets the same single-door rule for `ureq`.
- A test transport (a local `std::net::TcpListener`) lets a test read the exact request bytes, so the
  "version and platform only" criterion is checked by a test, not by reading code.

### The update manifest

- One JSON manifest per channel, `stable.json` and `beta.json`, published as assets of a fixed
  GitHub release named `update-manifest` (a stable URL, no GitHub Pages). It lists, per platform and
  architecture: version, minimum OS, package URL, size, SHA-256, and the release-notes URL.
- Signed with **minisign** (Ed25519). CI signs with the `minisign` tool (ISC, CI only); the app
  verifies with **minisign-verify** (MIT, no dependencies) against a public key compiled into the
  app. The trusted comment carries the channel and the publication time.
- The app refuses a manifest whose signature fails, whose channel differs, whose publication time is
  older than the last one it accepted, or that offers a version not newer than the running one. So a
  replayed or rolled-back manifest offers nothing.
- The secret key lives only in the protected `release` environment. A second key is generated and
  kept offline by the owner; rotating means one release signed by the old key that carries the new
  public key.

### Checking and downloading

- Check: once a day and on Check now, never before first run is complete, never when the switch is
  off. Download: only when "Download updates automatically" is on or the user asks. Both go through
  `net` with purpose `UpdateCheck`, so both are logged.
- A downloaded package is kept in the app data directory and accepted only when its size, SHA-256
  and the OS signature match: `SecStaticCodeCheckValidity` with a requirement on Ferman's Team ID on
  macOS, `WinVerifyTrust` plus the publisher name on Windows.

### Installing

- **macOS: Sparkle 2 as the installer only** (MIT, with its bundled permissive parts), in the
  Developer ID build. After `net` has downloaded and verified the archive, the app writes a local
  appcast pointing at the file and asks Sparkle to install on quit. Sparkle's own EdDSA check runs as
  a second check. Sparkle never fetches anything over the network: its automatic checks are off and
  its feed URL is the local file. This needs Sparkle's installer XPC services and its two
  `mach-lookup` temporary-exception entitlements, plus `com.apple.security.network.client`.
  W3 starts with a one-day spike. If Sparkle refuses a local feed, we write our own unsandboxed
  installer XPC service on Sparkle's design, and this ADR comes back to the owner.
- **Windows: Inno Setup 6**, per user by default (`PrivilegesRequired=lowest`, no UAC prompt on a
  silent update), per machine on request. One installer each for x64 and arm64. It registers the
  `Ferman.PDF` ProgID and `.pdf\OpenWithProgids` under `HKCU\Software\Classes` and removes them on
  uninstall. The app runs the verified installer on quit with `/VERYSILENT /SUPPRESSMSGBOXES
  /NORESTART /CLOSEAPPLICATIONS`, and the installer starts Ferman again. Inno Setup's licence is
  an unusual licence under ADR 0016 and needs the owner's approval; its notice goes into
  DEPENDENCIES.md and the release notices.
- **Unsaved documents** survive an update restart through the existing recovery journal (ADR 0008):
  quitting for an update writes recovery files instead of asking to save. The next launch reopens
  them without the a1-12 prompt and says so once.

### Managed installs

- **Homebrew:** the cask declares `auto_updates false`. The app treats itself as managed when its
  bundle path resolves into a `Caskroom` directory, read through a read-only temporary-exception
  entitlement for `/opt/homebrew/Caskroom/ferman/` and `/usr/local/Caskroom/ferman/`.
- **winget:** the manifest passes `/MANAGED=winget`; the installer records it in the registry, and
  the app reads it.
- **Flatpak:** detected through `/.flatpak-info`; Flathub updates it.
- **AppImage:** never updates itself. The check still runs when it is on and offers the release page.
- A managed install shows "Managed by Homebrew", "Managed by winget" or "Managed by Flathub" in a11-1i,
  and never downloads or installs anything ([G53](../DESIGN_GAPS.md#g53)).

### Packaging

- **macOS:** the universal Release build, signed inside out with the Developer ID, the hardened
  runtime and a timestamp (PDFium, the Rust library, `ferman-mcp`, Sparkle, the app), in a plain
  `hdiutil` UDZO DMG, signed, notarized with `notarytool` and stapled.
- **Windows:** x64 on `windows-2025` and arm64 on `windows-11-arm`. Every shipped `.exe` and `.dll`
  is Authenticode-signed with an RFC 3161 timestamp, and the installer and uninstaller too.
- **Linux:** x64 only in M5. A Flatpak that repackages the release tarball (the manifest lives in
  the repository; submission to Flathub waits for the app id), and an AppImage built with appimagetool
  (MIT) on the type-2 runtime that uses the system GTK, so only the runtime's libfuse is LGPL. That
  runtime needs either a named exception from the owner or the AppImage is replaced by a plain
  `.tar.gz`.
- **Release workflow:** a `vX.Y.Z` or `vX.Y.Z-beta.N` tag builds everything, signs it in the
  protected `release` environment, and publishes a draft GitHub Release with the packages,
  `SHA256SUMS` signed with minisign, release notes written by git-cliff (MIT OR Apache-2.0, CI only)
  from Conventional Commits, and the third-party notices as one text file. It also writes the
  Homebrew cask and winget manifest and checks them with `brew audit --cask` and `winget validate`.
  The owner publishes the draft; submitting the cask and manifest upstream is a manual step in
  `docs/RELEASING.md`.

Out of scope: delta updates, the Mac App Store and the Microsoft Store, Linux arm64 packages, PAC
proxies, a server of Ferman's own.

## Consequences

### Positive

- Every byte the updater fetches goes through the gateway, its switch and its log.
- No C build step for TLS (no aws-lc, no OpenSSL), about 35 crates in all, all on the allow list.
- A replayed or downgraded manifest offers nothing.
- Sparkle's installer is a maintained answer to the hardest part, the bundle swap under the sandbox.

### Negative

- Sparkle ships in the app and its entitlements widen the sandbox slightly.
- Inno Setup's licence is not on the standard list; the AppImage runtime is LGPL.
- ring needs clang to build for Windows arm64.
- The Homebrew check needs another temporary-exception entitlement.
- The macOS 12 VM check and the update between two real releases can only be run by the owner.

### Follow-up

- M5 W1 to W5, as in the [M5 plan](../PROGRESS.md#m5-plan).
- ARCHITECTURE §10, DEPENDENCIES.md, `deny.toml`, `tools/licenses/about.toml` and THIRD_PARTY_NOTICES
  in the commits that add each piece.

## Alternatives considered

- **reqwest (blocking).** About 95 crates with tokio, hyper and tower; its default TLS brings aws-lc
  with a cmake build. Not needed for one GET at a time.
- **ureq with native-tls.** Links the system OpenSSL on Linux, which complicates the AppImage.
- **ed25519-dalek with raw keys.** Fine, but minisign gives the CI tool, the file format and the
  trusted comment for free, and verifies with a crate that has no dependencies.
- **Sparkle and WinSparkle as whole frameworks.** They bypass the gateway and the activity log.
- **Dropping the macOS sandbox.** Simplest for the bundle swap; it changes an approved decision and
  weakens the app.
- **MSIX.** No stub code, but App Installer updates outside the gateway and there is no classic
  ProgID. **WiX:** MS-RL. **NSIS:** clumsier, no arm64 stub; the fallback if Inno Setup is refused.

## References

- [Brief](../BRIEF.md) §3, §7 (M5)
- [ADR 0008](0008-file-safety-and-saving.md), [ADR 0009](0009-threading-and-jobs.md),
  [ADR 0015](0015-privacy-and-network.md), [ADR 0016](0016-dependency-licence-policy.md)
- [Q01](../QUESTIONS.md#q01), [Q02](../QUESTIONS.md#q02), [Q03](../QUESTIONS.md#q03),
  [Q12](../QUESTIONS.md#q12), [Q15](../QUESTIONS.md#q15); [G53](../DESIGN_GAPS.md#g53)
