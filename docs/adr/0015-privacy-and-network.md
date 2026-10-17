# ADR 0015: Privacy and network use

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §1 and §3. On 2026-10-16 the owner added OCSP and CRL revocation lookups as a
  fifth network use, off until first use, with their own switch in Settings › Privacy and an entry
  in the network activity log (phase 3), ruled out local-network discovery and phone pairing
  ([Q06](../QUESTIONS.md#q06)), and settled the update-check endpoint ([Q15](../QUESTIONS.md#q15)).
  The same day the owner confirmed that document JavaScript is never run and that Ferman says so
  ([Q13](../QUESTIONS.md#q13)), and approved the pub network deny list, Proposed in M1. The sections
  below follow these answers (brought in line on 2026-10-17).
- **Supersedes:** none
- **Superseded by:** none

## Context

"No account, no telemetry; documents never leave the device" ([brief §1](../BRIEF.md)). And: "Privacy:
no telemetry. Network is used only for: update check (can be disabled), optional language-pack
downloads, optional AI (local model or the user's own key), signature timestamp servers. List all of
them in Settings → Privacy." ([brief §3](../BRIEF.md))

The design takes privacy seriously but does not match the brief everywhere:

- **a1-2b** (onboarding) lists one network use, "One optional check for updates", and says signing needs
  no connection ([G24](../DESIGN_GAPS.md#g24)).
- **a11-1h** (Settings › Privacy) says "No usage data, no crash reports, no document contents, no
  account. Files stay on this device." It lists five connections, each with a switch: Check for updates
  ("Once a day; sends only the version number and platform"), **Signature checks** (revocation lookups
  "when you sign or open a signed file"), Timestamps, Downloads you start (OCR language packs and the
  assistant's model), and Your AI provider (off). It links to "Show network activity…". Revocation
  lookups (OCSP and CRL) are not among the brief's four ([G51](../DESIGN_GAPS.md#g51)).
- **a7-4** (Scan to PDF) adds Wi-Fi scanner discovery and phone pairing over the local network, not
  listed anywhere in Privacy ([G52](../DESIGN_GAPS.md#g52), [G56](../DESIGN_GAPS.md#g56)).
- **a10-2** and **a11-1g**: the assistant runs on the device or with the user's own API key. a10-2 says
  what each sends: "Local model: nothing, ever. Own key: only your question and the parts of the open
  document needed to answer it, to that provider and nowhere else."
- `fm-additions.css` loads fonts from Google Fonts at run time ([G07](../DESIGN_GAPS.md#g07)).
- The security report (a8-4) says "JavaScript is never run; Ferman says it blocked it" and "External
  links list their destinations before anyone clicks them".

## Decision

### What Ferman never does

- No telemetry, analytics, crash reporting service or usage statistics. No account, no sign-in, no
  identifiers.
- Documents, their text, their names and rendered pages never leave the device through Ferman. The one
  exception is the optional AI assistant, which is off by default: when the user turns it on with their
  own key for an online provider, their question and the passages of the open document needed to
  answer it go to that provider and nowhere else. The setup (a10-2) says so before anything is sent. A
  local model sends nothing.
- No fonts, images or other resources are fetched at run time for the UI. The design's Google Fonts
  import is never used ([ADR 0013](0013-fonts-and-icons.md)).
- No network access triggered by document content: no remote fonts or file specifications fetched, no
  form submission, no link prefetching, no `/Launch` actions. A `/URI` link opens in the OS browser only
  when the user clicks it after seeing the address. Document JavaScript is never executed, and Ferman
  tells the user when a document contains scripts (confirmed by the owner on 2026-10-16,
  [Q13](../QUESTIONS.md#q13); the PDFium build has no JavaScript engine,
  [ADR 0004](0004-lopdf-model-pdfium-renderer.md)). No board draws that notice; its form is Proposed
  with the M2 plan ([G100](../DESIGN_GAPS.md#g100)).
- Logs stay on the device ([ADR 0010](0010-error-handling-no-panics.md)).

<a id="the-only-four-network-uses"></a>

### The only network uses

The brief's four uses, and a fifth the owner added on 2026-10-16 ([Q06](../QUESTIONS.md#q06)):

| Use | When it connects | Default | First milestone |
|---|---|---|---|
| Update check | once a day and on "Check now" | on; can be turned off in a11-1h and a11-1i | M5 |
| Language-pack downloads (OCR packs; the local AI model counts under AI) | only when the user starts a download | used only on request | P3 |
| AI with the user's own key, or downloading a local model | only when the user turns the assistant on and uses it | off | P4 |
| Signature timestamp servers | only when the user signs with a timestamp, to the server they chose | used only when signing | P3 |
| Revocation lookups (OCSP and CRL), added by the owner | only when a signature is checked or made with "Signature checks" on (a11-1h) | off until first use | P3 |

- The update check sends only the version number and platform, as a11-1h says. The owner settled the
  endpoint and payload on 2026-10-16 ([Q15](../QUESTIONS.md#q15)): one HTTPS request for a static,
  signed manifest per channel (Stable, Beta) served from GitHub (Releases or Pages), with no server of
  Ferman's own, no cookies and no identifiers; the versions are compared on the device, and update
  packages are verified with their signature before they are installed.
- UI translations are bundled with the app, not downloaded ([G52](../DESIGN_GAPS.md#g52)).
- A timestamp request sends a hash, never the document. A revocation lookup asks about the
  certificate, never the document.
- All five are listed in **Settings › Privacy** (a11-1h), each with its own switch. The onboarding
  (a1-2b) lists the brief's four, each "off until you use it" except the update check, as export
  `519d42a` draws it; revocation lookups join that list when phase 3 builds them
  ([G24](../DESIGN_GAPS.md#g24)).

### Uses the design draws but the brief does not list

- **OCSP and CRL revocation lookups** (a11-1h "Signature checks", [G51](../DESIGN_GAPS.md#g51)) are
  allowed (the owner, 2026-10-16, [Q06](../QUESTIONS.md#q06)): off until first use, with their own
  switch in Settings › Privacy, through the gateway below and with an entry in the activity log. They
  are built with signature validation in phase 3; until then the drawn "Signature checks" row stays
  visible but disabled, like any feature that is not built.
- **Local-network scanner discovery and phone pairing** (a7-4, [G56](../DESIGN_GAPS.md#g56)) are not
  built. Scan to PDF (phase 3) offers only the scanners the operating system provides; pairing, and
  the mobile "Send to my computer" path, are reconsidered with the mobile apps in phase 5.

### One network gateway

- One module in ferman-api (`net`) is the only code with an HTTP client. It arrives with the update
  check in M5. Other crates that need the network (timestamping in P3, for example) receive a gateway
  handle; they never open connections themselves.
- cargo-deny enforces this: HTTP client crates are allowed only when ferman-api depends on them directly
  (`wrappers`), and the CI check of the dependency graph (`crate_graph`, approved on 2026-10-16,
  [ADR 0003](0003-crate-layout-and-api-boundary.md)) backs it up
  ([ADR 0016](0016-dependency-licence-policy.md)).
- Every request names its purpose (update check, language pack, AI provider, timestamp,
  revocation). The gateway checks the user's switch for that purpose, refuses if it is off, and
  appends an entry to the local **network activity log** (time, purpose, host, bytes) shown by "Show
  network activity…" in a11-1h. The log never leaves the device.
- Requests carry no cookies and no identifiers, use TLS with the OS trust store and the OS proxy
  settings, and identify themselves only as `Ferman/<version> (<os>; <arch>)`: the version and platform
  that a11-1h discloses, and nothing else. The platform part tells the update check which file to offer,
  as the owner settled on 2026-10-16 ([Q15](../QUESTIONS.md#q15)).
- The Flutter app adds no networking packages. **Approved by the owner on 2026-10-16** (Proposed in
  [ROADMAP.md](../ROADMAP.md) M1 step 2 until then): CI fails if `pubspec.lock` contains an HTTP
  client, font downloader (such as google_fonts), analytics or crash-reporting package from a deny
  list. It runs as the `pub_denylist` check in `tools/checks`.
- Opening a link in the OS browser is the browser's network use, started by the user; it is not a
  Ferman connection.

### Later platforms

The same rules apply to the web build and the mobile apps (P5). On the web, documents are processed in
the browser and never uploaded.

## Consequences

### Positive

- The privacy promise is enforced by structure (one gateway, dependency rules, CI checks), not by
  convention.
- Users can see and switch off every connection, and see a log of what happened.
- Ferman works fully offline except for the update check and the optional uses above.

### Negative

- Without telemetry, we learn about crashes and usage only from user reports. The local crash log and
  "Copy crash log" (a1-12) make reports easier.
- Revocation checks are part of good signature validation. They are off until first use
  ([Q06](../QUESTIONS.md#q06)), so until the user turns on "Signature checks", P3 validation can only
  use data embedded in the document and the user's trust store, and must say so.
- The deny-list checks need maintenance as packages change.

### Follow-up

- M1 (done): the pub licence check and the pubspec network deny list (`pub_denylist`, approved on
  2026-10-16); the Settings › Privacy skeleton with the five drawn switches off and disabled, with
  "Available in a future version" (a11-1h-m1, [G89](../DESIGN_GAPS.md#g89)).
- M2: a CI step that runs the integration test under `strace` on Linux and fails on any internet
  connection (Proposed with the [M2 plan](../PROGRESS.md#m2-plan)).
- M4: full Privacy pane and activity log view.
- M5: the gateway with the update check ([Q15](../QUESTIONS.md#q15)).
- P3: timestamps, language packs and revocation lookups through the gateway, as the owner decided in
  Q06.

## Alternatives considered

- **Opt-in telemetry.** Useful data, but the brief says no telemetry, with no exception.
- **Let each crate use the network directly.** Easier, but impossible to audit and easy to break.
- **Follow the design's five uses as drawn.** The fifth (revocation) is not in the brief. The owner
  allowed it on 2026-10-16, but off until first use rather than on by default as a11-1h draws it
  ([Q06](../QUESTIONS.md#q06)).
- **No update check at all.** Simplest, but the brief includes one, and users would miss security fixes.
  Builds installed through a package manager (Homebrew, winget) may turn it off, since the package
  manager handles updates ([G53](../DESIGN_GAPS.md#g53)).

## References

- [Brief](../BRIEF.md) §1, §3
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 9.2 and 10
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0004](0004-lopdf-model-pdfium-renderer.md),
  [ADR 0010](0010-error-handling-no-panics.md), [ADR 0013](0013-fonts-and-icons.md),
  [ADR 0016](0016-dependency-licence-policy.md)
- Artboards a1-2b, a7-4, a8-4, a10-2, a11-1g, a11-1h, a11-1h-m1, a11-1i
- [G07](../DESIGN_GAPS.md#g07), [G24](../DESIGN_GAPS.md#g24), [G51](../DESIGN_GAPS.md#g51),
  [G52](../DESIGN_GAPS.md#g52), [G53](../DESIGN_GAPS.md#g53), [G56](../DESIGN_GAPS.md#g56),
  [G89](../DESIGN_GAPS.md#g89), [G100](../DESIGN_GAPS.md#g100)
- [Q06](../QUESTIONS.md#q06), [Q13](../QUESTIONS.md#q13), [Q15](../QUESTIONS.md#q15)
