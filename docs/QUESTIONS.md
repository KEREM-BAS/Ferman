# Questions for the owner

These are the questions that need, or needed, the owner's decision. Brief §9 says to put open
questions here and continue with the safest option. Every entry therefore names the option in force
until the owner answers, so work does not stop and nothing is built on an unapproved change by
accident.

Brief §8 asks Milestone 0 to end with at least three questions: the bundle identifier
([Q01](#q01)), the publisher name for code signing ([Q02](#q02)) and the minimum macOS and Windows
versions ([Q03](#q03)). The others came up during discovery and planning. The owner answered the
first batch with the M0 go-ahead on 2026-10-15; [Q18](#q18) was added at the start of M1 and
[Q19](#q19) after the M1 bridge benchmark. The owner answered every remaining question on
2026-10-16, when M1 was merged. [Q21](#q21) came up while planning M2 and [Q22](#q22) with the
open path (M2 W1); both are open.

Related: [design gaps](DESIGN_GAPS.md) · [roadmap](ROADMAP.md) · [architecture](ARCHITECTURE.md) ·
[dependencies](DEPENDENCIES.md) · [ADRs](adr/README.md) · [progress](PROGRESS.md)

## Contents

1. [How to answer](#how-to-answer)
2. [Entry format](#entry-format)
3. [Summary](#summary)
4. [Questions](#questions)

## How to answer

- Answer in any form: a reply to the M0 summary, a GitHub issue or comment, or an edit to this file.
  A short answer such as "Q04: yes" is enough.
- The answer is written into the entry with its date, and the status becomes **Answered**.
- The documents that depend on it follow in the same change: the ADR status, the linked
  [DESIGN_GAPS.md](DESIGN_GAPS.md) entries (from Needs owner to Decided or Resolved), and
  [ROADMAP.md](ROADMAP.md), [DEPENDENCIES.md](DEPENDENCIES.md) or [ARCHITECTURE.md](ARCHITECTURE.md)
  where they mention the question.
- New questions get the next free id, Q21 onwards. Ids are never reused, so links stay valid.

### Status values

| Status | Meaning |
|---|---|
| Open | Waiting for the owner. The default in the entry is in force. |
| Answered | The owner has decided. The answer and its date are in the entry. |
| Answered in part | The owner decided some parts. The entry says which parts stay open; their default is still in force. |
| Withdrawn | No longer needed. The entry says why. |

## Entry format

Each entry starts with an HTML anchor, so other documents can link to it as `QUESTIONS.md#q07`:

```markdown
<a id="qNN"></a>

### QNN · Short title

- **Question:** what the owner is asked to decide
- **Why it matters:** what depends on the answer
- **Options:** the realistic choices, with their costs
- **Proposal:** the option recommended
- **Meanwhile:** what is in force until the owner answers
- **Needed by:** the milestone, or the step, that the answer blocks
- **Status:** Open, Answered or Answered in part (with date), or Withdrawn
- **Related:** ADRs, design gaps and other questions
- **Answer:** none yet
```

## Summary

| ID | Question | Needed by | Status |
|---|---|---|---|
| [Q01](#q01) | Bundle identifier | M1 step 2 | Answered 2026-10-15: `io.github.kerembas.ferman` |
| [Q02](#q02) | Code-signing publisher name | M5 | Answered 2026-10-16: one name; an individual Apple membership unless an organisation exists; Azure Trusted Signing or an organisation-validated certificate, else SignPath |
| [Q03](#q03) | Minimum OS versions and architectures | M1 step 2 | Answered 2026-10-15 |
| [Q04](#q04) | Approve ADR 0007: harfrust instead of rustybuzz | M1 step 1 | Answered 2026-10-15: harfrust |
| [Q05](#q05) | Confirm eight mode tabs, including Tools | M1 step 8 | Answered 2026-10-15: eight tabs |
| [Q06](#q06) | Network uses the design adds: OCSP and CRL, local network | M4 (Privacy rows); P3 | Answered 2026-10-16: revocation allowed, off until first use; only the system's scanners, no pairing |
| [Q07](#q07) | Approve ADR 0018: OS-native file pickers | M2 | Answered 2026-10-16: native pickers; ADR 0018 Accepted |
| [Q08](#q08) | Fonts to bundle: Hebrew, Devanagari, CJK, handwriting, similar fonts | M1 step 5; M3; M4 | Answered 2026-10-15 and 2026-10-16: all four groups (handwriting and similar fonts bundled) |
| [Q09](#q09) | Missing-glyph default as designed | M3 | Answered 2026-10-16: the design's default, and the `fsType` detail |
| [Q10](#q10) | Milestones for drawn features the roadmap does not name | M2 | Answered 2026-10-16: the proposal |
| [Q11](#q11) | Design re-export and fixes, or DESIGN_GAPS decisions as final | none blocked; M1 gains most | Answered 2026-10-16: (c), the missing files with the next export, boards for the riskiest gaps |
| [Q12](#q12) | Linux packaging formats and window chrome | M1 step 8; M5 | Answered 2026-10-15 and 2026-10-16: custom title bar; Flatpak and AppImage in M5 |
| [Q13](#q13) | Document JavaScript is never executed | M2 | Answered 2026-10-16: never run, and say so |
| [Q14](#q14) | Copyright holder "The Ferman Authors"; commit sign-off | M1 | Answered 2026-10-15 and 2026-10-16: "The Ferman Authors"; DCO sign-off required from M2 |
| [Q15](#q15) | Update check: endpoint and payload | M5 | Answered 2026-10-16: a signed manifest served from GitHub (Releases or Pages); the release files on GitHub Releases |
| [Q16](#q16) | OCR engine | P3 | Answered 2026-10-16: chosen at the start of phase 3; Tesseract the fallback |
| [Q17](#q17) | Approve three licence exceptions and the reading of "GPL-compatible" | M1 (CI cache); M2 | Answered 2026-10-15 and 2026-10-16: three exceptions; the stricter reading confirmed |
| [Q18](#q18) | macOS App Sandbox | before M2 | Answered 2026-10-16: keep the sandbox if M2 shows it works, else off for the Developer ID build |
| [Q19](#q19) | Tile transfer across the bridge: which zero-copy path | before M2 step 3 | Answered 2026-10-16: the Dco codec first, then the pointer view, then textures |
| [Q20](#q20) | AI clients (Claude, ChatGPT and others) working in Ferman through MCP | M4 step 11 | Answered 2026-10-16: after M3, live in the running app, set up from Settings; details as proposed |
| [Q21](#q21) | Memory-mapping the private snapshot of a file over 256 MB (an `unsafe` exception) | M2 step 2 | Open |
| [Q22](#q22) | The password copy PDFium keeps while an encrypted document is open | the M2 review | Open |

## Questions

<a id="q01"></a>

### Q01 · Bundle identifier

- **Question:** Which reverse-DNS identifier should Ferman use as its bundle and application id?
- **Why it matters:** The id is how each operating system knows the app. On macOS it is the
  `CFBundleIdentifier`: Gatekeeper, notarization and keychain entries use it, and so does the
  folder `~/Library/Application Support/<bundle id>/` that holds recovery files
  ([ADR 0008](adr/0008-file-safety-and-saving.md)). On Windows it feeds the installer, the file
  associations and the winget package. On Linux it names the desktop file, and Flatpak requires a
  reverse-DNS application id. The iOS and Android apps (phase 5) need one too. It must be based on a
  domain or account you control, so nobody else can claim it. It cannot change after the first
  release without breaking settings, recovery paths, file associations and updates.
- **Options:**
  1. A domain you own, for example `org.<your-domain>.ferman`. The most durable choice, but the
     domain must stay registered.
  2. Your GitHub account: `io.github.kerem-bas.ferman`. No domain needed, and Flathub accepts
     `io.github.<user>.<project>` ids that it can verify through the repository. It is tied to the
     account name.
  3. The domain of a future organisation, if Ferman moves to one. It must exist before the first
     release.
- **Proposal:** option 2, unless you own or plan to own a domain for Ferman. Some platforms restrict
  the characters in an id (some Linux and D-Bus ids do not allow hyphens, so Linux may need
  `io.github.kerem_bas.Ferman`); M1 checks the exact form for each platform.
- **Meanwhile:** superseded by the answer. The id is final from M1 step 2 on; no placeholder is
  used.
- **Needed by:** M1 step 2 (platform projects).
- **Status:** Answered on 2026-10-15
- **Related:** [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0008](adr/0008-file-safety-and-saving.md), [Q02](#q02), [Q12](#q12), [Q18](#q18)
- **Answer:** `io.github.kerembas.ferman` on every platform. It has no hyphen or underscore, so the
  same form works as the macOS `CFBundleIdentifier`, the Linux application id and a D-Bus or Flatpak
  id. The Flutter projects are created with the organisation `io.github.kerembas` and the project
  name `ferman`.
  - **Note for M5 (Flathub).** Flathub verifies an `io.github.<user>` id against the GitHub account
    `<user>`. The repository's account is `KEREM-BAS`, not `kerembas`, so publishing on Flathub would
    need a GitHub account or organisation named `kerembas`, or a domain-based id for the Flatpak.
    This is raised again with the Linux packaging part of [Q12](#q12) before M5.

<a id="q02"></a>

### Q02 · Code-signing publisher name

- **Question:** Under which name should releases be signed: the Apple Developer ID team name on
  macOS, and the subject of the Authenticode certificate on Windows?
- **Why it matters:** The name is what people see when they install Ferman: in Gatekeeper on macOS,
  and as the "Verified publisher" in the Windows permission prompt and SmartScreen. Apple and the
  certificate authority verify it. An individual account shows your legal name. An organisation
  account shows the organisation's legal name and needs a registered legal entity (Apple asks for a
  D-U-N-S number). SmartScreen builds reputation per certificate and publisher, so changing the name
  later loses that reputation. Unsigned builds are blocked or flagged on both systems, and the
  bundled PDFium library is signed together with the app.
- **Options:**
  - macOS: (a) an individual Apple Developer Program membership, signed with your legal name;
    (b) an organisation membership, signed with the organisation's name.
  - Windows: (a) an organisation-validated code-signing certificate from a commercial certificate
    authority, in your name or the organisation's (the key must live on a hardware token or in a
    cloud key store); (b) SignPath Foundation's free signing for open-source projects, where the
    publisher shown is the foundation, not Ferman; (c) Azure Trusted Signing, Microsoft's managed
    signing service, where eligibility depends on identity validation and country.
  - Linux packages and release checksums are signed with a project key, whatever the answer here.
- **Proposal:** one name on both platforms. Use an individual Apple membership unless an
  organisation exists. On Windows, use Azure Trusted Signing or an organisation-validated
  certificate in the same name if available to you, and SignPath Foundation otherwise.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, development and CI builds stay
  unsigned. M4 runs a signing dry run with a test certificate (see [ROADMAP.md](ROADMAP.md)).
  Nothing is published as a release before an answer.
- **Needed by:** M5. Enrolment and certificate validation can take weeks, so an early answer helps.
- **Status:** Answered on 2026-10-16
- **Related:** [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md), [Q01](#q01), [Q14](#q14)
- **Answer:** the proposal: one publisher name on both platforms. On macOS, an individual Apple
  Developer Program membership, signed with the owner's legal name, unless an organisation exists.
  On Windows, Azure Trusted Signing or an organisation-validated certificate in the same name if
  available, and SignPath Foundation otherwise.


<a id="q03"></a>

### Q03 · Minimum OS versions and architectures

- **Question:** Which operating-system versions and processor architectures must Ferman support?
- **Why it matters:** The answer sets the deployment targets in the Flutter platform projects, the
  CI matrix, which PDFium binaries ship, and which OS features Ferman can use without fallbacks
  (file pickers and sandbox bookmarks, atomic file replacement, portals on Linux). Ferman's users
  are office and public-sector staff, who often work on older managed machines. Lower minimums
  reach more people but cost testing and workarounds.
- **Options:** the proposal below, or higher or lower minimums for each platform.
- **Proposal:**
  - macOS 12 Monterey or later, as one universal build (arm64 and x86_64).
  - Windows 10 22H2 and Windows 11, on x64 and arm64. Windows 10 reached its end of support in
    October 2025, but many managed office machines still run it, some with extended security
    updates.
  - Linux, best effort: x64 and arm64 on glibc-based distributions, for example Ubuntu 22.04 or
    later.
  - M1 checks these against the minimums of Flutter 3.47.7 and of the PDFium binaries. Where
    Flutter needs more, its minimum wins and this entry is updated.
- **Meanwhile:** superseded by the answer.
- **Needed by:** M1 step 2 (deployment targets and the CI matrix).
- **Status:** Answered on 2026-10-15
- **Related:** [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0018](adr/0018-native-file-pickers.md), [G15](DESIGN_GAPS.md#g15), [Q12](#q12), [Q18](#q18)
- **Answer:** the proposal.
  - macOS 12 Monterey or later, one universal build (arm64 and x86_64). The deployment target is
    12.0.
  - Windows 10 22H2 and Windows 11, on x64 and arm64.
  - Linux, best effort: glibc-based distributions from Ubuntu 22.04 on. CI builds on Ubuntu 22.04 as
    well as the current runner to prove the floor.
  - M1 step 2 checks these against the minimums of Flutter 3.47.7 and the PDFium binaries. If either
    needs more, its minimum wins and this entry says so. Builds that the development container and CI
    cannot run (arm64 apps, Windows 10) are recorded as pending owner checks in
    [PROGRESS.md](PROGRESS.md).

<a id="q04"></a>

### Q04 · Approve ADR 0007: harfrust instead of rustybuzz

- **Question:** May ferman-fonts shape text with harfrust instead of rustybuzz, which brief §3
  names?
- **Why it matters:** Shaping turns text into positioned glyphs for every edit Ferman writes into a
  PDF: Arabic and Persian joining forms, Devanagari clusters, ligatures and kerning in Latin
  scripts, and CJK. rustybuzz is archived upstream and points its users to harfrust, so it gets no
  more fixes, including security fixes on a path that reads untrusted fonts. harfrust (0.14.0, MIT)
  is the maintained successor in the HarfBuzz organisation and uses read-fonts, the same font
  parser as skrifa, so Ferman parses fonts with one library instead of two. The brief fixes this
  library, so changing it needs your approval (brief §3 and §9).
- **Options:** (a) harfrust, pinned to an exact version; (b) rustybuzz, as the brief says;
  (c) HarfBuzz itself through C bindings, the most mature option, at the cost of a C dependency and
  build work on three systems.
- **Proposal:** (a), as [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) describes.
- **Meanwhile:** superseded by the answer.
- **Needed by:** M1 step 1, which sets the ferman-fonts dependencies and the cargo-deny bans.
- **Status:** Answered on 2026-10-15
- **Related:** [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md),
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md), [DEPENDENCIES.md](DEPENDENCIES.md)
- **Answer:** (a), harfrust. [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) is Accepted.
  harfrust is pinned exactly and added when shaping is first used (M3). rustybuzz is never a direct
  dependency: from M1 step 1, `deny.toml` bans it except as krilla's wrapper
  (`{ crate = "rustybuzz", wrappers = ["krilla"] }`).

<a id="q05"></a>

### Q05 · Confirm eight mode tabs, including Tools

- **Question:** Should the mode bar have the eight tabs that every artboard draws: View, Edit,
  Comment, Fill & Sign, Organize, Convert, Protect and Tools?
- **Why it matters:** The design disagrees with itself. FmWindow and every board with a mode bar
  show eight tabs, while the design system's `FERMAN_MODES` constant and its readme list seven,
  without Tools. Tools holds Compress and Version history (M4), basic Print (proposed for M4,
  [Q10](#q10)) and later tools: Compare, Accessibility, PDF/A & preflight, Batch actions, Measure and
  AI assistant. The brief does not list the modes. The mode bar is built in M1.
- **Options:** (a) eight tabs as drawn; (b) seven tabs as the design system constant says, with the
  Tools items moved somewhere no board draws, such as a menu or other modes.
- **Proposal:** (a).
- **Meanwhile:** superseded by the answer.
- **Needed by:** M1 step 8 (app shell).
- **Status:** Answered on 2026-10-15
- **Related:** [G09](DESIGN_GAPS.md#g09),
  [ADR 0011](adr/0011-flutter-state-navigation-components.md)
- **Answer:** (a), eight mode tabs as drawn, including Tools. Later-phase Tools items are visible but
  disabled with "Available in a future version". [G09](DESIGN_GAPS.md#g09) is Decided.

<a id="q06"></a>

### Q06 · Network uses the design adds

- **Question:** May Ferman use the network for OCSP and CRL certificate revocation checks, and for
  scanner discovery and phone pairing on the local network?
- **Why it matters:** Brief §3 allows exactly four network uses: the update check, optional
  language-pack downloads, optional AI, and signature timestamp servers. The design adds more:
  - revocation lookups when signing or opening a signed file (a11-1h "Signature checks", on by
    default; a11-1e; long-term validation, PAdES-B-LT, by default in a5-5b and a5-6);
  - Wi-Fi scanner discovery and phone-as-camera pairing over the local network (a7-4);
  - "Send to my computer…" from the mobile app (a13-8f).

  Revocation data makes signature validation trustworthy and lets signatures stay verifiable for
  years, which matters for Turkish e-imza. Without it, validation can only use data already in the
  file and must say that revocation was not checked.
- **Options:**
  - Revocation: (a) allowed, off until first use, with its own switch in Settings › Privacy and an
    entry in the network activity log; (b) allowed and on by default, as drawn; (c) not allowed:
    validation uses embedded data and says when revocation was not checked, and signing defaults
    to PAdES-B-T.
  - Local network: (a) discovery and pairing allowed, off until first use, with their own switch;
    (b) only the scanners the operating system provides, and no pairing; (c) left out.
- **Proposal:** revocation (a). Local network (b) for phase 3, and pairing reconsidered with the
  mobile apps in phase 5.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, none of these is enabled. The
  drawn rows and switches stay visible but disabled. Nothing is built before phase 3.
- **Needed by:** M4 decides which rows Settings › Privacy shows; P3 builds the features.
- **Status:** Answered on 2026-10-16
- **Related:** [G24](DESIGN_GAPS.md#g24), [G51](DESIGN_GAPS.md#g51), [G52](DESIGN_GAPS.md#g52),
  [G56](DESIGN_GAPS.md#g56), [ADR 0015](adr/0015-privacy-and-network.md)
- **Answer:** the proposal. Revocation (a): OCSP and CRL lookups are allowed, off until first use,
  with their own switch in Settings › Privacy and an entry in the network activity log. They become
  a fifth network use beside the brief's four, listed in Settings › Privacy; [ADR
  0015](adr/0015-privacy-and-network.md) follows when phase 3 builds them. Local network (b): Scan
  to PDF (phase 3) offers only the scanners the operating system provides; Ferman does no
  local-network discovery and no phone pairing, which is reconsidered with the mobile apps in phase
  5.

<a id="q07"></a>

### Q07 · Approve ADR 0018: OS-native file pickers

- **Question:** May Ferman use the operating system's own pickers to open a file, choose a save
  location and choose a folder, as the only exception to the brief's custom-dialog rule?
- **Why it matters:** Brief §6 says dialogs are custom design-system widgets. File pickers are
  different. In sandboxed builds (the Mac App Store, Flatpak, Snap, the web, iOS and Android) only
  the system picker can give Ferman access to a file the user chose. People also rely on the
  picker's favourites, cloud drives, network locations and accessibility. The design draws a custom
  Save as sheet (a1-11) with "Other location…", "Choose a folder…" in a6-2 and a7-2, and no open
  dialog at all.
- **Options:** (a) native pickers for opening, save location and folder only, while Ferman's a1-11
  sheet stays and hands off for "Other location…"; (b) a custom Ferman file browser, which cannot
  work in sandboxed builds; (c) native pickers everywhere, including Save as, which drops the drawn
  a1-11 sheet.
- **Proposal:** (a), as [ADR 0018](adr/0018-native-file-pickers.md) describes.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, M1 builds no picker; entry
  points that would open one stay visible and disabled with "Available in a future version". If M2
  starts before an answer, the OS-native open picker is used as the safest option (brief §9), and in
  M3 the native save-location handoff from a1-11; each milestone summary flags it again for
  approval, as ADR 0018 says.
- **Needed by:** M2 (open dialog); M3 (Save as).
- **Status:** Answered on 2026-10-16
- **Related:** [ADR 0018](adr/0018-native-file-pickers.md), [G25](DESIGN_GAPS.md#g25),
  [G26](DESIGN_GAPS.md#g26), [G28](DESIGN_GAPS.md#g28), [Q12](#q12), [Q18](#q18)
- **Answer:** (a), the proposal: OS-native pickers for opening a file, choosing a save location and
  choosing a folder are the only exception to the custom-dialog rule. Ferman's a1-11 Save as sheet
  stays and hands off to the native panel for "Other location…". [ADR
  0018](adr/0018-native-file-pickers.md) is Accepted.

<a id="q08"></a>

### Q08 · Fonts to bundle

- **Question:** Beyond IBM Plex Sans, Serif, Mono and Sans Arabic, which fonts should ship with the
  app?
- **Why it matters:** Brief §2 says fonts come from the design, and scripts the bundled fonts do not
  cover fall back to system fonts. The design names more faces than that core set and loads them
  from Google Fonts at run time, which Ferman never does ([G07](DESIGN_GAPS.md#g07)). Every font
  adds size to the app and a licence to ship. Four groups need a decision:
  1. **IBM Plex Sans Hebrew and IBM Plex Sans Devanagari** (OFL-1.1, small) for the Hebrew and Hindi
     UI, as the design's UI font stack names them. Without them, Hebrew and Hindi use system fonts.
  2. **CJK.** IBM's Plex Sans JP, KR, SC and TC releases are tens to hundreds of megabytes, so
     Japanese, Korean and Chinese use system fonts ([ADR 0013](adr/0013-fonts-and-icons.md)).
     Downloadable font packs would be a new network use.
  3. **Handwriting faces for typed signatures** (M4): Caveat and Dancing Script (OFL-1.1) and
     Homemade Apple (Apache-2.0), the design's `--font-hand-1..3`.
  4. **Similar document fonts for missing glyphs** (M3): the a3-3b group "Similar fonts included
     with Ferman" shows Cormorant Garamond and Crimson Pro (both OFL-1.1). Any font shipped for this
     must allow embedding.
- **Options:** bundle each group or not; for group 2, system fonts only or optional font packs.
- **Proposal:** bundle groups 1, 3 and 4 as unmodified upstream files with their licences; CJK from
  system fonts, with no font packs.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, for the open groups 3 and 4: no
  handwriting fonts ship, so typed signatures wait while drawn and image signatures work;
  missing-glyph step 3 offers embedded fonts, installed fonts and the bundled Plex families.
- **Needed by:** M1 step 5 (groups 1 and 2, answered), M3 (group 4), M4 (group 3).
- **Status:** Answered on 2026-10-15 (groups 1 and 2) and 2026-10-16 (groups 3 and 4)
- **Related:** [ADR 0013](adr/0013-fonts-and-icons.md) (Accepted),
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md), [G06](DESIGN_GAPS.md#g06),
  [G07](DESIGN_GAPS.md#g07), [G08](DESIGN_GAPS.md#g08)
- **Answer:**
  - Group 1: bundle **IBM Plex Sans Hebrew** and **IBM Plex Sans Devanagari** (IBM releases 1.1.0,
    400, 500 and 600), as unmodified TTFs with their OFL-1.1 licence files, from M1 step 5.
    [ADR 0013](adr/0013-fonts-and-icons.md) is Accepted in full.
  - Group 2: Japanese, Korean and Chinese use system fonts, with no font packs.
  - Groups 3 and 4 (2026-10-16): bundled, as proposed. Caveat, Dancing Script and Homemade Apple for
    typed signatures (M4), and Cormorant Garamond and Crimson Pro as similar fonts for missing
    glyphs (M3), each as the unmodified upstream files with its licence;
    [DEPENDENCIES.md](DEPENDENCIES.md) lists them when they are added.

<a id="q09"></a>

### Q09 · Missing-glyph default as designed

- **Question:** Is the design's default for a character the font cannot draw the right one? And, as
  a smaller detail proposed in ADR 0006: may Ferman stop reusing the glyphs of an embedded font whose
  OS/2 `fsType` allows at most preview and print?
- **Why it matters:** Brief §4: when an edit needs a glyph the embedded font lacks (for example ğ,
  ş or İ in a subset font), Ferman (1) uses the embedded glyph if present, (2) takes it from the
  same font if that font is installed, re-subsets and embeds it, and (3) otherwise offers similar
  fonts exactly as the design shows, never substituting silently. The design's Settings › Editing
  (a11-1c) defaults to "Use a similar font and say so": the closest font draws the character at
  once, the panel says so once and marks the character, and "Choose a font…" and "Keep as is" stay
  available. The other settings are "Ask each time" and "Keep the original font and mark the
  character". Ferman reads the default as compliant, because it is never silent, but "offer" could
  also mean "ask first". The OpenType specification expects documents with preview-and-print fonts
  to be opened read-only. [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md) proposes that
  editing text set in such an embedded font does not reuse its glyphs (step 1); step 2 applies only
  if the installed copy allows embedding; otherwise step 3 runs, with the reason shown. Text in other
  fonts stays editable, and font programs without an OS/2 table are not restricted.
- **Options:** (a) the design's default, "Use a similar font and say so"; (b) "Ask each time" as the
  default; (c) "Keep the original font and mark the character" as the default. For the `fsType`
  detail: (i) as proposed; (ii) reuse embedded glyphs whatever `fsType` says.
- **Proposal:** (a), and the `fsType` detail as proposed (i).
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, (a), with step 2 always tried
  first ([ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)). No text is edited before M3, so
  the `fsType` detail has no effect until then.
- **Needed by:** M3.
- **Status:** Answered on 2026-10-16
- **Related:** [G36](DESIGN_GAPS.md#g36), [G37](DESIGN_GAPS.md#g37),
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)
- **Answer:** (a) and (i), the proposal: the default stays the design's "Use a similar font and say
  so", with step 2 always tried first, and text set in an embedded font whose OS/2 `fsType` allows
  at most preview and print does not reuse its embedded glyphs ([ADR
  0006](adr/0006-font-pipeline-and-missing-glyphs.md)).

<a id="q10"></a>

### Q10 · Milestones for drawn features the roadmap does not name

- **Question:** Do you accept the proposed milestones for drawn features that brief §7 does not
  schedule?
- **Why it matters:** The design draws these features with no milestone tags, and the brief's
  roadmap does not name them. Until they are scheduled, their entry points are visible but disabled.
- **Options:** accept the proposal, move individual features, or mark some as out of scope (they
  would then stay disabled, with a BACKLOG entry saying so).
- **Proposal:**

  | Feature | Boards | Proposed |
  |---|---|---|
  | Layers (optional content) tab | a2-3c | M2 |
  | Basic system print | a9-6 | M4 |
  | Presentation mode, reading mode, split view, inverted dark reading | a2-5a, a2-5b, a2-8a, a2-8b, a2-9 | P2 |
  | Read aloud, measure and calibrate | a2-6, a4-1c, a9-7 | P4 |
  | Booklet, poster, separations | a9-6b, a9-6c, a9-6d | P5 |
  | Mobile night mode and read aloud, iPad split view | a13-4d, a14-1c | P5, with the mobile and tablet apps |

  Drawn features placed with the nearest roadmap item (crash recovery with saving, bookmarks and
  metadata editing, links, and others) are listed in [ROADMAP.md](ROADMAP.md) under "Not scheduled
  yet".
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, the proposal. Entry points stay
  disabled with "Available in a future version" until each feature ships.
- **Needed by:** M2 (layers), then M4 and each later phase.
- **Status:** Answered on 2026-10-16
- **Related:** [G33](DESIGN_GAPS.md#g33), [ROADMAP.md](ROADMAP.md)
- **Answer:** the proposal is accepted as the table above gives it.

<a id="q11"></a>

### Q11 · Design re-export and fixes

- **Question:** Will the designer provide a re-export and corrected boards, or should the decisions
  in [DESIGN_GAPS.md](DESIGN_GAPS.md) be treated as final?
- **Why it matters:** The export is incomplete. The desktop UI kit that the brief cites
  (`design/ui_kits/desktop/index.html`) does not exist, and the component sources, foundation
  guidelines, icon SVGs and licence files are missing ([G01](DESIGN_GAPS.md#g01) to
  [G04](DESIGN_GAPS.md#g04), [G08](DESIGN_GAPS.md#g08)). Many states and variants are not drawn:
  Linux chrome, Windows dialogs, dark, right-to-left and Turkish variants, empty and error states.
  Several boards need copy changes: GPL-3.0 to Apache-2.0, "Included" on later features, the list of
  network uses. Ferman never edits `design/`, so each fix either comes from the designer or stays a
  decision in DESIGN_GAPS.md.
- **Options:**
  - (a) A re-export with `ui_kits/`, component sources (`.jsx`, `.d.ts`), guidelines, icon SVGs,
    licence files and the additions merged, plus new or corrected boards for the gaps, delivered per
    milestone.
  - (b) No re-export: the DESIGN_GAPS decisions are final, and goldens built from them become the
    reference.
  - (c) A mix: the missing files now, and boards only for the riskiest gaps (M1 shell variants and
    the M3 editing states).
- **Proposal:** (c).
- **Meanwhile:** the DESIGN_GAPS decisions stand until a board of the new export replaces them.
  The `Fm*` building blocks, `_ds_bundle.js` and `_adherence.oxlintrc.json` are the source
  for components. Ferman builds undrawn states from existing components and records them in goldens.
  A re-export replaces `design/` only through a change you make or approve (brief §9). The
  repository already carries the OFL-1.1 (IBM Plex), ISC (Lucide) and MIT (Feather) texts for the
  third-party material inside `design/` in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md),
  outside `design/`. The app ships its own licence files in `app/assets` either way (brief §2).
- **Needed by:** no milestone is blocked. M1 (component library and shell) gains most from an early
  answer.
- **Status:** Answered on 2026-10-16
- **Related:** [G01](DESIGN_GAPS.md#g01), [G02](DESIGN_GAPS.md#g02), [G03](DESIGN_GAPS.md#g03),
  [G04](DESIGN_GAPS.md#g04), [G05](DESIGN_GAPS.md#g05), [G08](DESIGN_GAPS.md#g08),
  [G60](DESIGN_GAPS.md#g60), and every DESIGN_GAPS entry that asks for boards;
  [ADR 0012](adr/0012-design-token-pipeline.md), [ADR 0013](adr/0013-fonts-and-icons.md)
- **Answer:** (c), the proposal: the missing files (the desktop UI kit, the component sources and
  types, the guidelines, and where the seven added icons of [G60](DESIGN_GAPS.md#g60) come from)
  come with the next design-system export, and corrected or new boards come for the riskiest gaps.
  The owner is preparing those boards and adds the new export to `design/` in a change of their own;
  Ferman's documents and goldens follow it.

<a id="q12"></a>

### Q12 · Linux packaging formats and window chrome

- **Question:** Which Linux package formats should releases include, and should the Linux window use
  Ferman's own title bar or the system's?
- **Why it matters:** Linux is best effort (brief §1), and the design draws no Linux chrome
  ([G15](DESIGN_GAPS.md#g15)). The package format decides sandboxing (Flatpak and Snap reach files
  through portals, which ties into [Q07](#q07)), how updates arrive (through the package manager,
  not the in-app updater, [G53](DESIGN_GAPS.md#g53)), the application id ([Q01](#q01)) and what CI
  builds. The chrome decides the Linux title bar in M1.
- **Options:**
  - Formats: Flatpak on Flathub (sandboxed, wide reach, updates through Flathub); AppImage (one
    file, no sandbox, updates need extra work); `.deb` and `.rpm` (native packages, work per
    distribution); Snap; a plain archive.
  - Chrome: (a) client-side decorations drawn by Ferman, with the caption buttons at the end in the
    GNOME (libadwaita) style, matching the custom title bars on macOS and Windows; (b) the system's
    own decorations, with Ferman's tab, mode and tool rows below them.
- **Proposal:** Flatpak on Flathub plus an AppImage for M5; chrome (a).
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, for the open packaging part: no
  packaging before M5.
- **Needed by:** M1 step 8 (chrome, answered); M5 (packaging).
- **Status:** Answered on 2026-10-15 (window chrome) and 2026-10-16 (packaging)
- **Related:** [G15](DESIGN_GAPS.md#g15), [G53](DESIGN_GAPS.md#g53),
  [ADR 0018](adr/0018-native-file-pickers.md), [Q01](#q01), [Q03](#q03), [Q07](#q07)
- **Answer:** chrome (a): a custom Linux title bar with client-side decorations drawn by Ferman, the
  caption buttons at the end, Ctrl shortcuts and Cancel on the left in dialogs.
  [G15](DESIGN_GAPS.md#g15) is Decided.

  Packaging (2026-10-16): the proposal, a Flatpak on Flathub plus an AppImage, built in M5. The
  release files for macOS, Windows and Linux are published on GitHub Releases ([Q15](#q15)). The
  Flathub id check in [Q01](#q01) still applies.

<a id="q13"></a>

### Q13 · Document JavaScript is never executed

- **Question:** Do you confirm that Ferman never runs JavaScript embedded in PDF files?
- **Why it matters:** PDFs can carry JavaScript for form calculations, validation and formatting,
  and for actions when a document opens. Scripts are a common attack path, and a script engine is a
  large dependency. Some forms rely on scripts to compute totals or format dates; without them,
  those fields show their stored values and need typing by hand.
- **Options:** (a) never run document JavaScript, and tell the user when a document contains scripts
  that Ferman does not run; (b) (a), plus built-in support for the most common form helpers (number,
  date and percentage formats, simple sums) without a script engine; (c) run scripts in a sandboxed
  engine.
- **Proposal:** (a) now; consider (b) with form filling (M4) or form authoring (P4).
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, (a). The PDFium build Ferman
  ships has no JavaScript engine, and the engine never executes document scripts ([ADR
  0004](adr/0004-lopdf-model-pdfium-renderer.md), [ADR 0015](adr/0015-privacy-and-network.md)).
- **Needed by:** M2 (opening documents that contain scripts); M4 (form filling).
- **Status:** Answered on 2026-10-16
- **Related:** [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md),
  [ADR 0015](adr/0015-privacy-and-network.md), [ARCHITECTURE.md](ARCHITECTURE.md)
- **Answer:** (a), the proposal: Ferman never runs document JavaScript and tells the user when a
  document contains scripts that it does not run. (b), helpers for common form formats without a
  script engine, is considered with form filling (M4) or form authoring (P4).

<a id="q14"></a>

### Q14 · Copyright holder and commit sign-off

- **Question:** Should the copyright line read "Copyright The Ferman Authors"? And should every
  commit carry a DCO 1.1 `Signed-off-by:` line, enforced by a CI check from M1?
- **Why it matters:** The line appears in the About screen (a11-5), in the app's metadata (the
  macOS bundle and the Windows file properties), in installers and in notice files. With "The
  Ferman Authors", every contributor keeps the copyright in their own contribution and licenses it
  under Apache-2.0 (inbound equals outbound, no contributor licence agreement), and the git history
  records who the authors are. The Developer Certificate of Origin lets each contributor certify
  that they wrote a change or have the right to submit it under Apache-2.0.
  [CONTRIBUTING.md](../CONTRIBUTING.md) proposes it; without a CI check it stays optional and uneven.
- **Options:** (a) "The Ferman Authors"; (b) your legal name, with contributors credited; (c) a
  future organisation. Sign-off: (i) required from M1, with a CI check; (ii) welcome but not
  required; (iii) not used.
- **Proposal:** (a), and sign-off (i).
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, for the open sign-off part:
  sign-off is welcome but not required, and CI does not check it.
- **Needed by:** M1 (app metadata and About), M2 (the sign-off check); both answered.
- **Status:** Answered on 2026-10-15 (copyright holder) and 2026-10-16 (sign-off)
- **Related:** [ADR 0016](adr/0016-dependency-licence-policy.md),
  [CONTRIBUTING.md](../CONTRIBUTING.md), [LICENSE](../LICENSE)
- **Answer:** (a), "Copyright The Ferman Authors", in the app metadata (the macOS bundle and the
  Windows file properties), About, installers and notice files. The LICENSE file stays the
  unmodified Apache-2.0 text.

  Sign-off (2026-10-16): (i), required. Every commit carries a DCO 1.1 `Signed-off-by:` line from M2
  on, as M1 is merged; the first M2 pull request adds the CI check and updates
  [CONTRIBUTING.md](../CONTRIBUTING.md).

<a id="q15"></a>

### Q15 · Update check: endpoint and payload

- **Question:** Where should the update check connect, and what may it send?
- **Why it matters:** The update check is the only network use that is on by default (brief §3), so
  it must be small and easy to verify. a11-1h promises that it sends "the version number and
  platform"; a1-2b says "only the version number" ([G24](DESIGN_GAPS.md#g24)). The endpoint decides
  who sees the request, and any request shows the user's IP address to that server.
- **Options:**
  - Endpoint: (a) a static release manifest served from GitHub (Releases or Pages), with no server
    of our own; (b) the GitHub Releases API; (c) a Ferman server.
  - Payload: (a) nothing beyond the request itself, with versions compared on the device; (b) the
    version and platform, as a11-1h says, so the server can pick the right file.
  - Either way, update packages are verified with a signature before they are installed.
- **Proposal:** endpoint (a), with one manifest per channel (Stable, Beta) and a signature. One
  HTTPS request with no cookies and no identifiers; the user agent carries only the version and
  platform, matching a11-1h; the comparison happens on the device.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, no network code exists before
  M5.
- **Needed by:** M5.
- **Status:** Answered on 2026-10-16
- **Related:** [G24](DESIGN_GAPS.md#g24), [G53](DESIGN_GAPS.md#g53),
  [ADR 0015](adr/0015-privacy-and-network.md)
- **Answer:** the proposal, with the owner's note that the release files for macOS, Windows and
  Linux are published on the repository's GitHub Releases. The update check reads a static, signed
  manifest per channel (Stable, Beta) served from GitHub (Releases or Pages), with no server of
  Ferman's own: one HTTPS request with no cookies and no identifiers, a user agent carrying only the
  version and platform (as a11-1h says), and the comparison made on the device. Update packages are
  verified with their signature before they are installed.

<a id="q16"></a>

### Q16 · OCR engine

- **Question:** Which OCR engine should Ferman use in phase 3?
- **Why it matters:** OCR makes scanned pages searchable and editable (a3-11, a7-5). It should cover
  as many of the 21 UI languages' scripts as possible, Turkish first. ocrs, the engine brief §3 asks
  to verify, recognises only Latin script in its current preview, and the licence of its trained
  models is unclear. Model and language-data licences must pass Ferman's policy
  ([ADR 0016](adr/0016-dependency-licence-policy.md)), and OCR language packs are one of the four
  allowed network uses.
- **Options:** (a) ocrs with rten, if models for more scripts with a clear licence appear before
  phase 3; (b) Tesseract (Apache-2.0) with Leptonica (BSD-2-Clause): wide language coverage and
  trained data under Apache-2.0, at the cost of a C++ dependency on three systems; (c) another
  engine with ONNX models, after a licence review.
- **Proposal:** decide at the start of phase 3 after a fresh check. Tesseract is the fallback.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, no OCR before phase 3. OCR
  entry points are disabled with "Available in a future version".
- **Needed by:** P3.
- **Status:** Answered on 2026-10-16
- **Related:** [ADR 0016](adr/0016-dependency-licence-policy.md), [DEPENDENCIES.md](DEPENDENCIES.md),
  [ROADMAP.md](ROADMAP.md), [G29](DESIGN_GAPS.md#g29), [G39](DESIGN_GAPS.md#g39)
- **Answer:** the proposal: the engine is chosen at the start of phase 3 after a fresh check of ocrs
  and other engines, with Tesseract and Leptonica as the fallback.

<a id="q17"></a>

### Q17 · Approve three licence exceptions

- **Question:** May Ferman use three dependencies whose licences are outside the allow-list, and do
  you confirm the project's reading of "GPL-compatible"?
  1. `dbus` 0.7.x (MPL-2.0), which desktop_drop 0.8.4 depends on for every platform, for drag and
     drop in M2.
  2. `libfuzzer-sys` (adds NCSA for the vendored LLVM libFuzzer), only in the separate `fuzz/`
     workspace, which never ships, for the fuzz targets from M2.
  3. The Swatinem/rust-cache GitHub Action (LGPL-3.0), only in CI and never distributed, from M1.
  4. The reading: for an Apache-2.0 product, brief §3's "permissive or GPL-compatible" rules out GPL
     code of any version and LGPL as a sole licence, and allows MPL-2.0 only per package after your
     review.
- **Why it matters:** Brief §9 says to ask before adding a dependency with an unusual licence, and
  [ADR 0016](adr/0016-dependency-licence-policy.md) sends every MPL-2.0 case to you. desktop_drop
  imports `dbus` unconditionally, so its code and notice are in the macOS and Windows builds too,
  not only on Linux, and MPL-2.0 then requires a notice that names the licence and where the source
  is available. NCSA is permissive but not on the allow-list. rust-cache never reaches users, but its
  licence is LGPL-3.0. The reading decides which future dependencies are allowed: a literal reading
  would allow GPL-3.0 code, which would put Ferman's binaries under GPL-3.0.
- **Options:** approve or decline each part separately. `dbus`: (a) approve; (b) decline, and drag
  and drop uses another permissively licensed package or a platform channel. `libfuzzer-sys`:
  (a) approve; (b) decline, and the fuzz targets use a different harness, chosen and licence-checked
  in M2. rust-cache: (a) approve; (b) decline, and CI caches with actions/cache (MIT) or not at all.
  The reading: confirm it, or relax it through an ADR.
- **Proposal:** approve all three as named exceptions (a cargo-deny exception for `libfuzzer-sys`, a
  named skip in the pub licence check for `dbus`, rust-cache pinned by commit SHA), and confirm the
  reading.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, for the open part 4: the
  stricter reading applies ([DEPENDENCIES.md](DEPENDENCIES.md#1-policy)).
- **Needed by:** M1 (the CI cache) and M2 (drag and drop and the first fuzz targets), all answered.
  Part 4 blocks nothing while the stricter reading applies.
- **Status:** Answered on 2026-10-15 (parts 1 to 3) and 2026-10-16 (part 4)
- **Related:** [ADR 0016](adr/0016-dependency-licence-policy.md),
  [ADR 0017](adr/0017-testing-and-ci.md), [DEPENDENCIES.md](DEPENDENCIES.md), [Q16](#q16)
- **Answer:** parts 1 to 3 approved as named exceptions:
  1. `dbus` (MPL-2.0) through desktop_drop, from M2, unmodified and with its notice and source
     location in every build that includes desktop_drop. The pub licence check skips `dbus` by name,
     so any other MPL-2.0 package still fails.
  2. `libfuzzer-sys` (NCSA) only in the separate `fuzz/` workspace, which never ships, as a
     cargo-deny exception for that crate. `fuzz/` is created with the first parser in M2.
  3. Swatinem/rust-cache (LGPL-3.0) in CI only, pinned by commit SHA, never vendored or copied.

  Part 4 (2026-10-16): the reading is confirmed. No GPL code of any version, no LGPL-only code, and
  MPL-2.0 only per package after the owner's review.

<a id="q18"></a>

### Q18 · macOS App Sandbox

- **Question:** Should the macOS build keep the App Sandbox entitlement that Flutter's macOS
  template turns on?
- **Why it matters:** `flutter create` writes `com.apple.security.app-sandbox` into both macOS
  entitlement files. Under the sandbox, Ferman can read and write only its own container and the
  files the user grants: through the system open and save panels, drag and drop, or "Open with".
  - **File access and saving.** A file opened through the panel is granted on its own, not its
    folder. The temp file and atomic rename of [ADR 0008](adr/0008-file-safety-and-saving.md) then
    have to go through the system's replacement directory instead of a temp file next to the
    document.
  - **Recent files.** Reopening a recent file after a restart needs a security-scoped bookmark saved
    when the file was granted ([G28](DESIGN_GAPS.md#g28)).
  - **Pickers.** Only the system panels can grant access, which ties this to [Q07](#q07) and
    [ADR 0018](adr/0018-native-file-pickers.md).
  - **App data.** The app data directory moves into
    `~/Library/Containers/io.github.kerembas.ferman/`, which is where settings, autosave and
    recovery files would live.
  - **Distribution.** The Mac App Store requires the sandbox. The notarized DMG and Homebrew cask of
    M5 do not.
- **Options:** (a) keep the sandbox in every macOS build, with bookmarks for recent files and the
  system replacement directory for atomic saves; (b) turn it off for the Developer ID build (DMG and
  Homebrew) and keep the hardened runtime, which keeps file access simple but closes the Mac App
  Store path until it is turned back on; (c) two builds, sandboxed for the Mac App Store and
  unsandboxed for direct downloads.
- **Proposal:** (a), if M2 shows that recent files and the atomic save of ADR 0008 work under it;
  otherwise (b), with the reason recorded.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, M1 keeps the template's sandbox
  entitlement on. M1 opens no documents, so nothing depends on the answer yet. The M1 settings file
  goes to the app support directory that path_provider reports, which lies inside the container
  while the sandbox is on.
- **Needed by:** before M2 starts (opening files, recent files, file pickers).
- **Status:** Answered on 2026-10-16
- **Related:** [Q07](#q07), [Q01](#q01), [Q03](#q03), [ADR 0008](adr/0008-file-safety-and-saving.md),
  [ADR 0018](adr/0018-native-file-pickers.md), [G28](DESIGN_GAPS.md#g28),
  [ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)
- **Answer:** (a), the proposal: the App Sandbox stays on in every macOS build, with security-scoped
  bookmarks for recent files and the system's replacement directory for atomic saves, if M2 shows
  that both work under it. If they do not, (b): the Developer ID build (DMG and Homebrew) drops the
  sandbox and keeps the hardened runtime, with the reason recorded.
- **M2 experiment, first half (2026-10-30, the owner's MacBook Pro M5 Pro, sandboxed debug
  build):** security-scoped bookmarks work. A file opened from `~/Documents` through "Open with"
  was kept with its bookmark (`files.bookmarks.app-scope`); after a restart the recent files opened
  it through the bookmark, while one kept without a bookmark could not be read ("Ferman can't open").
  The second half, an atomic save through the system's replacement directory, comes with Save
  attachment as… (B110, M2 W3), the first write to a file the user chose, and is settled at the M2
  review.

<a id="q19"></a>

### Q19 · Tile transfer across the bridge

- **Question:** Which path should rendered tiles take from Rust to Dart, now that the default
  bridge codec copies them?
- **Why it matters:** The brief asks for 60 fps scrolling and zooming. The M1 benchmark moves 1 MiB
  in 3.3 ms at best in a profile build in the development container (median 5.9 ms), against a
  target of 0.2 ms on R1 and R2. The default SSE codec of flutter_rust_bridge 2.13 copies a
  `Vec<u8>` byte by byte and again on the Dart side, so a zoom step with dozens of tiles would spend
  its frame on copies. The numbers and the options are in
  [ADR 0009](adr/0009-threading-and-jobs.md#tile-transfer-m1-measurements-and-options-proposed).
- **Options:** (a) the Dco codec (`full_dep: true`): generated, no hand-written unsafe code, but
  codegen needs ffigen and libclang, and the M1 trial needs a fix for a name clash before it
  compiles; (b) an opaque Rust pixel buffer that Dart reads through a pointer view with a native
  finalizer: zero copy, but a small hand-written unsafe `extern "C"` surface in ferman-api, an
  exception to [ADR 0010](adr/0010-error-handling-no-panics.md); (c) a platform texture registry:
  native code on three systems and a `Texture` widget per tile.
- **Proposal:** (a) first, measured on R1 and R2 with `flutter drive --profile`; (b) if (a) misses
  the budget; (c) only if both fail.
- **Meanwhile:** superseded by the answer of 2026-10-16. Until then, M1 keeps the default codec. M1
  moves no tiles, so nothing depends on the answer yet. Running the profile benchmark on R1 and R2
  is an owner check ([PROGRESS.md](PROGRESS.md#measurements)).
- **Needed by:** before M2 step 3 (tiles and the viewer).
- **Status:** Answered on 2026-10-16
- **Related:** [ADR 0009](adr/0009-threading-and-jobs.md), [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0010](adr/0010-error-handling-no-panics.md), [ARCHITECTURE.md §3.4](ARCHITECTURE.md#34-tiles)
- **Answer:** the proposal: (a) first, the Dco codec, measured on R1 and R2 with `flutter drive
  --profile`; (b) only if (a) misses the budget; (c) only if both fail. Option (b) needs a small
  hand-written unsafe surface in ferman-api, an exception to [ADR
  0010](adr/0010-error-handling-no-panics.md), so it is built only with the owner's approval of that
  surface, as [ADR 0009](adr/0009-threading-and-jobs.md) says. ADR 0009 is Accepted with the other
  Proposed items of M1 ([PROGRESS.md](PROGRESS.md#owner-decisions-in-force-2026-10-15)).
- **Trial, 2026-10-19:** option (a) works and the bridge uses it. The M1 name clash came from the
  codegen's cbindgen pass reading the facade, now hidden from it. A 1 MiB transfer took 26 µs at
  the minimum and 73 µs at the median in a profile build on the owner's MacBook Pro (Apple M5 Pro),
  against 665 µs and 1,053 µs with the old codec; R1 and R2 are still to be measured
  ([ADR 0009](adr/0009-threading-and-jobs.md#tile-transfer-m1-measurements-and-options-proposed)).

<a id="q20"></a>

### Q20 · AI clients through MCP

- **Question:** Should AI assistants such as Claude and ChatGPT be able to work on the documents open
  in Ferman, with everything the app supports, through the Model Context Protocol (MCP), and how?
- **Why it matters:** It is a new way into the engine besides the UI and the CLI, and what a connected
  client reads goes to its provider, which touches the brief's privacy promise (brief §3,
  [ADR 0015](adr/0015-privacy-and-network.md)). It needs the editing engine (M3) to be useful.
- **Options:** (a) a server that works on files without the app, like the CLI; (b) a server in the
  running app, whose edits show live and can be undone; (c) both from one crate.
- **Proposal:** (b), after M3, off by default, set up from Settings, listed in Settings → Privacy,
  reachable only from the same computer ([ADR 0019](adr/0019-ai-clients-through-mcp.md)).
- **Meanwhile:** nothing is built before M4 step 11.
- **Needed by:** M4 step 11.
- **Status:** Answered on 2026-10-16: the direction, then the details
- **Related:** [ADR 0019](adr/0019-ai-clients-through-mcp.md), [ADR 0015](adr/0015-privacy-and-network.md),
  [G94](DESIGN_GAPS.md#g94), [Q13](#q13)
- **Answer:** The owner, 2026-10-16: yes, planned after M3. It works with the Ferman app open, locally.
  In Settings, Ferman gives a connection link for each client it can support (Claude, ChatGPT and
  others), or opens the client already set up. Anything that turns out to be a problem while building
  it is asked then.

  The details (2026-10-16): the owner approved the Proposed details of [ADR
  0019](adr/0019-ai-clients-through-mcp.md) as written, together with the other Proposed items of
  M1. Anything that changes when M4 step 11 starts goes back to the owner.

<a id="q21"></a>

### Q21 · Memory-mapping large files

- **Question:** May ferman-core memory-map the private snapshot of a file over 256 MB through one
  reviewed `memmap2` call site, an exception to the no-`unsafe` rule?
- **Why it matters:** The owner approved on 2026-10-16 that files above 256 MB are copied to a private
  snapshot in the cache directory and mapped from there ([ADR 0008](adr/0008-file-safety-and-saving.md),
  [ARCHITECTURE.md §5.1](ARCHITECTURE.md#51-open)). Mapping a file is `unsafe` in Rust: the compiler
  cannot rule out that another process changes the file while it is mapped. Every crate but ferman-api
  forbids `unsafe` code, and any further exception is a documented, reviewed one
  ([ADR 0010](adr/0010-error-handling-no-panics.md)). Without a mapping, a 2 GB file costs 2 GB of
  memory while it is open; with one, the operating system pages it in as needed.
- **Options:** (a) allow one `unsafe` call to `memmap2::Mmap::map` in a small module of ferman-core,
  on the snapshot only (never the user's file), with the reason in a `// SAFETY:` comment, its own
  `allow(unsafe_code)` entry in the check that fails on any other, and the snapshot opened read-only
  in a directory only Ferman writes; (b) no mapping: read every file into an owned buffer, and refuse
  files larger than the memory limit with a clear message (`ResourceLimit`).
- **Proposal:** (a). The snapshot is Ferman's own private copy, so the reason mapping is unsafe (someone
  else changing the file) does not arise in practice.
- **Meanwhile:** (b) without the refusal: M2 reads every file into an owned buffer, as the approved
  rule does below 256 MB, and records the open question in BACKLOG. Files over 256 MB open, using
  more memory.
- **Needed by:** M2 step 2 (the open path), or the M2 review at the latest.
- **Status:** Open
- **Related:** [ADR 0008](adr/0008-file-safety-and-saving.md), [ADR 0010](adr/0010-error-handling-no-panics.md),
  [ARCHITECTURE.md §5.1](ARCHITECTURE.md#51-open), [.claude/rules/rust.md](../.claude/rules/rust.md)
- **Answer:** none yet

<a id="q22"></a>

### Q22 · The password copy PDFium keeps

- **Question:** ROADMAP §6 step 2 says passwords are wiped from memory after key derivation. Ferman
  can wipe its own copies but not PDFium's. Is that enough for M2, or should PDFium render an
  encrypted document from a decrypted copy so that it never gets the password?
- **Why it matters:** Since M2, ferman-core unlocks and decrypts encrypted documents with its own
  security handler, and every buffer it derives from the password is wiped when dropped, so the
  password never reaches lopdf ([ARCHITECTURE.md §9.2](ARCHITECTURE.md#92-untrusted-content-rules)).
  PDFium, which renders the pages, needs the password as well: pdfium-render copies it into a C
  string, and PDFium keeps it in its parser while the document is open. Both are freed without being
  wiped, and Ferman cannot reach them without `unsafe` code. A password reused elsewhere could then be
  read from a memory dump taken while the document is open, or from freed memory after it closes. The
  Dart string the password arrives in cannot be wiped either.
- **Options:** (a) keep PDFium's copy and narrow the criterion to "Ferman's own copies are wiped; the
  copy PDFium keeps while the document is open, and the UI's string, are not"; (b) give PDFium a
  decrypted copy written by lopdf in memory (a full rewrite, never on disk), so it gets no password.
  That costs a second copy of the document in memory, a slower first page for encrypted files (lopdf
  parses and writes before PDFium sees anything), and PDFium renders lopdf's rewrite instead of the
  original bytes, which the pixel tests would have to cover.
- **Proposal:** (a) for M2, with (b) assessed with the writer in M3, when lopdf's rewrite is tested
  against PDFium anyway.
- **Meanwhile:** (a): PDFium gets the password; ferman-core and ferman-render wipe theirs.
- **Also decides:** showing and hiding layers in a document opened with its password (BACKLOG
  B111). PDFium loads the document again for each change and needs the password then; the engine
  does not keep it, so those eye buttons stay disabled. Option (b) needs no password; with (a), the
  engine could keep its own wiped copy until the document closes, as PDFium keeps its unwiped one.
- **Needed by:** the M2 review.
- **Status:** Open
- **Related:** [ARCHITECTURE.md §9.2](ARCHITECTURE.md#92-untrusted-content-rules),
  [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md), ROADMAP §6 step 2
- **Answer:** none yet
