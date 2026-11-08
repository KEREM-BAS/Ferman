# signing

The code-signing dry run of M4 ([ROADMAP §8](../../docs/ROADMAP.md#8-m4-rest-of-phase-1), exit
checks), so M5 starts with a signing path that works. CI's Flutter job runs it on the release
build of macOS and Windows. Both scripts sign a copy, never the build itself, with an identity they
make and throw away, and need no secret and no account. They need sudo without a password (macOS)
or an elevated shell (Windows) to trust that identity for a moment, so they are CI only.

| Platform | Script | What it does |
|---|---|---|
| macOS | `dry-run-macos.sh <Ferman.app>` | A self-signed code-signing certificate in a temporary keychain, trusted for code signing until the script ends; signs inside out (`Contents/Frameworks`, deepest first, then `ferman-mcp`, then the app with `app/macos/Runner/Release.entitlements`) with the hardened runtime and no timestamp; `codesign --verify --deep --strict`; checks the authority and the sandbox entitlement |
| Windows | `dry-run-windows.ps1 <Release folder>` | A self-signed code-signing certificate in `CurrentUser\My`, trusted in `LocalMachine\Root` until the script ends; signs every `.exe` and `.dll` (`ferman.exe`, `ferman-mcp.exe`, the engine, Flutter and PDFium) with SHA-256 through the SDK's `signtool`, and verifies each |
| Linux | none | Linux packages are signed by their repositories (M5, Linux packaging) |

What M5 adds for a real release:

- **macOS:** an Apple Developer ID Application certificate and notarization credentials (an App
  Store Connect API key), kept as secrets of a protected CI environment; signing with
  `--timestamp` (Apple's timestamp server); `notarytool submit --wait`, then `stapler staple`. The
  sandboxed app and its helper `ferman-mcp` may need their own entitlements once the MCP socket is
  checked under the sandbox (ADR 0019).
- **Windows:** a code-signing certificate in the publisher's name ([Q02](../../docs/QUESTIONS.md#q02))
  on a hardware token or a cloud signing service, a timestamp server (`/tr` with `/td SHA256`), and
  the installer signed as well. A new publisher has no SmartScreen reputation at first.
- **Both:** PDFium's unsigned binaries signed with the app, as here.
